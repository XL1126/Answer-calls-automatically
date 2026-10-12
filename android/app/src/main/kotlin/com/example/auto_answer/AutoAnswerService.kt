package com.example.auto_answer

import android.Manifest
import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.pm.PackageManager
import android.graphics.Path
import android.graphics.Rect
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telecom.TelecomManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.content.ContextCompat
import java.util.Calendar

/**
 * 自动接听 + 通话录音无障碍服务。
 *
 * 接听策略（按优先级）：
 * 1. TelecomManager.acceptRingingCall()（需 ANSWER_PHONE_CALLS，部分系统可直接接通）
 * 2. 无障碍查找“接听”节点并点击
 * 3. 无障碍手势上滑接听
 *
 * 录音策略：
 * 通话进入 OFFHOOK 后启动 [CallRecorder]，IDLE 时停止并保存到应用私有目录。
 */
class AutoAnswerService : AccessibilityService() {

    private enum class Decision { IGNORE, ANSWER, REJECT }

    private val handler = Handler(Looper.getMainLooper())
    private var telephonyManager: TelephonyManager? = null
    private var phoneStateAvailable = false
    private var screenRinging = false

    private val callRecorder by lazy { CallRecorder(this) }
    private var lastNumber: String = ""
    private var answerScheduled = false

    private val phoneStateListener = object : PhoneStateListener() {
        @Deprecated("Deprecated in Java")
        override fun onCallStateChanged(state: Int, incomingNumber: String?) {
            handleCallState(state, incomingNumber)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        registerTelephony()
    }

    private fun registerTelephony() {
        try {
            telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
            // 仅使用 PhoneStateListener：可同时拿到状态与来电号码（需 READ_CALL_LOG）。
            // 不注册 TelephonyCallback，避免双重回调导致重复接听/录音。
            telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
            phoneStateAvailable = true
        } catch (_: SecurityException) {
            phoneStateAvailable = false
        } catch (_: Throwable) {
            phoneStateAvailable = false
        }
    }

    private fun handleCallState(state: Int, incomingNumber: String?) {
        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                val n = incomingNumber?.let(::normalize)?.takeIf { it.isNotEmpty() }
                if (n != null) lastNumber = n
                onIncomingCall(n)
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                cancelPendingAnswer()
                onCallConnected()
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                cancelPendingAnswer()
                onCallEnded()
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) return

        val root = rootInActiveWindow ?: return
        val hasRingUi = findNode(root, ANSWER_HINTS, ANSWER_ID_HINTS) != null
        val hasDeclineUi = findNode(root, DECLINE_HINTS, DECLINE_ID_HINTS) != null

        if (hasRingUi && hasDeclineUi) {
            if (!screenRinging) {
                screenRinging = true
                // 系统监听不可用时，用界面检测兜底；可用时不重复触发决策
                if (!phoneStateAvailable || !answerScheduled) {
                    onIncomingCall(extractNumberFromScreen().takeIf { it.isNotEmpty() } ?: lastNumber.ifEmpty { null })
                }
            }
        } else if (screenRinging && !hasRingUi) {
            screenRinging = false
            // 来电界面消失：可能已接通或已挂断
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        try {
            callRecorder.stop()
        } catch (_: Throwable) {
        }
        RecordForegroundService.stop(this)
        handler.removeCallbacksAndMessages(null)
        try {
            telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
        } catch (_: Throwable) {
        }
        super.onDestroy()
    }

    // ---------- 决策 ----------

    private fun onIncomingCall(number: String?) {
        val settings = Prefs.load(this)
        if (!settings.enabled) return
        val resolved = number?.let(::normalize)?.takeIf { it.isNotEmpty() }
            ?: extractNumberFromScreen()
        if (resolved.isNotEmpty()) lastNumber = resolved
        when (decisionFor(resolved, settings)) {
            Decision.IGNORE -> Unit
            Decision.ANSWER -> scheduleAnswer(settings, resolved)
            Decision.REJECT -> scheduleReject(resolved)
        }
    }

    private fun decisionFor(number: String, s: AnswerSettings): Decision {
        if (s.quietEnabled && !inQuietWindow(s)) return Decision.IGNORE
        return when (s.filterMode) {
            Prefs.FILTER_WHITELIST ->
                if (s.whitelist.any { matches(it, number) }) Decision.ANSWER else Decision.IGNORE
            Prefs.FILTER_BLACKLIST_BLOCK ->
                if (s.blacklist.any { matches(it, number) }) Decision.REJECT else Decision.ANSWER
            else -> Decision.ANSWER
        }
    }

    private fun inQuietWindow(s: AnswerSettings): Boolean {
        val cal = Calendar.getInstance()
        val now = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        val start = s.quietStartMinutes
        val end = s.quietEndMinutes
        return if (start <= end) now in start..end else now >= start || now <= end
    }

    private fun normalize(raw: String): String = raw.filter { it.isDigit() }

    private fun matches(entry: String, number: String): Boolean {
        val e = normalize(entry)
        if (e.isEmpty() || number.isEmpty()) return false
        if (number == e) return true
        return (e.length >= 7 && number.endsWith(e)) ||
            (number.length >= 7 && e.endsWith(number))
    }

    // ---------- 接听 / 拒接 ----------

    private fun scheduleAnswer(settings: AnswerSettings, number: String) {
        cancelPendingAnswer()
        answerScheduled = true
        val delayMs = (settings.delaySeconds.coerceIn(0, 60)) * 1000L
        handler.postDelayed({
            answerScheduled = false
            if (!performAnswer(settings, number)) {
                retryAnswer(settings, number, MAX_ATTEMPTS - 1)
            }
        }, delayMs)
    }

    private fun performAnswer(settings: AnswerSettings, number: String): Boolean {
        // 1) 系统 API
        if (trySystemAnswer()) {
            Prefs.addHistory(this, number.ifEmpty { "未知号码" }, "接听")
            return true
        }
        // 2) 无障碍节点点击 / 手势
        val node = rootInActiveWindow?.let { findNode(it, ANSWER_HINTS, ANSWER_ID_HINTS) }
        if (node != null) {
            actOnAnswer(node)
            Prefs.addHistory(this, number.ifEmpty { "未知号码" }, "接听")
            return true
        }
        return false
    }

    private fun retryAnswer(settings: AnswerSettings, number: String, attemptsLeft: Int) {
        if (attemptsLeft <= 0) return
        handler.postDelayed({
            if (performAnswer(settings, number)) return@postDelayed
            retryAnswer(settings, number, attemptsLeft - 1)
        }, RETRY_INTERVAL_MS)
    }

    private fun trySystemAnswer(): Boolean {
        return try {
            val tm = getSystemService(TELECOM_SERVICE) as TelecomManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION", "MissingPermission")
                tm.acceptRingingCall()
                true
            } else {
                false
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun scheduleReject(number: String) {
        cancelPendingAnswer()
        handler.postDelayed({
            if (!performReject(number)) {
                retryReject(number, MAX_ATTEMPTS - 1)
            }
        }, 0L)
    }

    private fun performReject(number: String): Boolean {
        val node = rootInActiveWindow
            ?.let { findNode(it, DECLINE_HINTS, DECLINE_ID_HINTS) }
        if (node != null) {
            if (node.isClickable) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            } else {
                val rect = Rect()
                node.getBoundsInScreen(rect)
                dispatchSwipe(
                    rect.exactCenterX(), rect.exactCenterY(),
                    rect.exactCenterX(), rect.exactCenterY() + SWIPE_DISTANCE
                )
            }
            Prefs.addHistory(this, number.ifEmpty { "未知号码" }, "拒接")
            return true
        }
        return false
    }

    private fun retryReject(number: String, attemptsLeft: Int) {
        if (attemptsLeft <= 0) return
        handler.postDelayed({
            if (performReject(number)) return@postDelayed
            retryReject(number, attemptsLeft - 1)
        }, RETRY_INTERVAL_MS)
    }

    private fun actOnAnswer(node: AccessibilityNodeInfo) {
        if (node.isClickable) {
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            return
        }
        val rect = Rect()
        node.getBoundsInScreen(rect)
        // 接听通常向上滑动
        dispatchSwipe(
            rect.exactCenterX(), rect.exactCenterY(),
            rect.exactCenterX(), rect.exactCenterY() - SWIPE_DISTANCE
        )
    }

    private fun dispatchSwipe(x1: Float, y1: Float, x2: Float, y2: Float) {
        try {
            val path = Path().apply {
                moveTo(x1, y1)
                lineTo(x2, y2)
            }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, SWIPE_DURATION_MS))
                .build()
            dispatchGesture(gesture, null, null)
        } catch (_: Throwable) {
        }
    }

    private fun cancelPendingAnswer() {
        answerScheduled = false
        handler.removeCallbacksAndMessages(null)
    }

    // ---------- 录音控制 ----------

    private fun onCallConnected() {
        val settings = Prefs.load(this)
        if (settings.speakerphone || settings.autoRecord) {
            enableSpeaker()
        }
        if (!settings.autoRecord) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        // 稍等片刻，待音频通路稳定
        handler.postDelayed({
            val number = lastNumber.ifEmpty { "未知号码" }
            val result = callRecorder.start(number)
            if (result != null) {
                RecordForegroundService.start(this)
                if (callRecorder.needsSpeakerForCapture()) {
                    enableSpeaker()
                }
            }
        }, RECORD_START_DELAY_MS)
    }

    private fun onCallEnded() {
        val file = callRecorder.stop()
        RecordForegroundService.stop(this)
        if (file != null && file.length() > 0) {
            Prefs.addHistory(this, lastNumber.ifEmpty { "未知号码" }, "录音")
        }
        lastNumber = ""
        screenRinging = false
    }

    private fun enableSpeaker() {
        try {
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            am.mode = AudioManager.MODE_IN_CALL
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // 新 API：尽量走扬声器
                val devices = am.availableCommunicationDevices
                val speaker = devices.firstOrNull {
                    it.type == android.media.AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                }
                if (speaker != null) {
                    am.setCommunicationDevice(speaker)
                    return
                }
            }
            @Suppress("DEPRECATION")
            am.isSpeakerphoneOn = true
        } catch (_: Throwable) {
        }
    }

    // ---------- 节点查找 ----------

    private fun findNode(
        root: AccessibilityNodeInfo,
        textHints: List<String>,
        idHints: List<String>
    ): AccessibilityNodeInfo? {
        val visited = HashSet<Int>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.addLast(root)
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            val key = System.identityHashCode(node)
            if (!visited.add(key)) continue

            val contentDesc = node.contentDescription?.toString()?.lowercase().orEmpty()
            val text = node.text?.toString()?.lowercase().orEmpty()
            val viewId = node.viewIdResourceName?.lowercase().orEmpty()
            val matched = textHints.any { contentDesc.contains(it) || text.contains(it) } ||
                idHints.any { viewId.contains(it) }
            if (matched) return node

            for (i in 0 until node.childCount) {
                try {
                    node.getChild(i)?.let { queue.addLast(it) }
                } catch (_: Throwable) {
                }
            }
        }
        return null
    }

    private fun extractNumberFromScreen(): String {
        val root = rootInActiveWindow ?: return ""
        val pattern = Regex("[+\\d][\\d\\s\\-()]{5,}")
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.addLast(root)
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            val t = node.text?.toString()
            if (!t.isNullOrBlank()) {
                val m = pattern.find(t)
                if (m != null) {
                    val n = normalize(m.value)
                    if (n.length in 6..15) return n
                }
            }
            for (i in 0 until node.childCount) {
                try {
                    node.getChild(i)?.let { queue.addLast(it) }
                } catch (_: Throwable) {
                }
            }
        }
        return ""
    }

    companion object {
        private const val MAX_ATTEMPTS = 6
        private const val RETRY_INTERVAL_MS = 500L
        private const val SWIPE_DISTANCE = 280
        private const val SWIPE_DURATION_MS = 250L
        private const val RECORD_START_DELAY_MS = 800L

        private val ANSWER_HINTS = listOf(
            "answer", "接听", "应答", "接听电话", "接听来电", "accept"
        )
        private val ANSWER_ID_HINTS = listOf(
            "answer", "accept", "incoming_call_answer", "call_accept", "接听"
        )
        private val DECLINE_HINTS = listOf(
            "decline", "reject", "end call", "hang up", "拒接", "挂断", "拒绝", "decline_call"
        )
        private val DECLINE_ID_HINTS = listOf(
            "decline", "reject", "end_call", "hangup", "incoming_call_decline", "拒接"
        )
    }
}
