package com.example.auto_answer

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSettings" -> result.success(settingsMap())
                    "setEnabled" -> {
                        Prefs.sp(this).edit()
                            .putBoolean(Prefs.KEY_ENABLED, call.arguments as? Boolean ?: true)
                            .apply()
                        result.success(null)
                    }
                    "setDelay" -> {
                        Prefs.sp(this).edit()
                            .putInt(Prefs.KEY_DELAY, (call.arguments as? Number)?.toInt() ?: 0)
                            .apply()
                        result.success(null)
                    }
                    "setSpeakerphone" -> {
                        Prefs.sp(this).edit()
                            .putBoolean(Prefs.KEY_SPEAKER, call.arguments as? Boolean ?: false)
                            .apply()
                        result.success(null)
                    }
                    "setFilterMode" -> {
                        Prefs.sp(this).edit()
                            .putInt(Prefs.KEY_FILTER_MODE, (call.arguments as? Number)?.toInt() ?: 0)
                            .apply()
                        result.success(null)
                    }
                    "setWhitelist" -> {
                        Prefs.writeList(Prefs.sp(this), Prefs.KEY_WHITELIST, Prefs.toStringList(call.arguments))
                        result.success(null)
                    }
                    "setBlacklist" -> {
                        Prefs.writeList(Prefs.sp(this), Prefs.KEY_BLACKLIST, Prefs.toStringList(call.arguments))
                        result.success(null)
                    }
                    "setQuietHours" -> {
                        val m = call.arguments as? Map<*, *>
                        Prefs.sp(this).edit()
                            .putBoolean(Prefs.KEY_QUIET_ENABLED, m?.get("enabled") as? Boolean ?: false)
                            .putInt(Prefs.KEY_QUIET_START, (m?.get("start") as? Number)?.toInt() ?: 0)
                            .putInt(Prefs.KEY_QUIET_END, (m?.get("end") as? Number)?.toInt() ?: 0)
                            .apply()
                        result.success(null)
                    }
                    "setAutoRecord" -> {
                        Prefs.sp(this).edit()
                            .putBoolean(Prefs.KEY_AUTO_RECORD, call.arguments as? Boolean ?: true)
                            .apply()
                        result.success(null)
                    }
                    "getHistory" -> result.success(Prefs.getHistory(this).toString())
                    "clearHistory" -> {
                        Prefs.clearHistory(this)
                        result.success(null)
                    }
                    "requestPermission" -> {
                        requestRuntimePermissions()
                        result.success(null)
                    }
                    "openAccessibility" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())

                    // ---- 录音管理 ----
                    "getRecordings" -> result.success(RecordingStore.list(this).toString())
                    "deleteRecording" -> {
                        val name = call.arguments as? String ?: ""
                        result.success(RecordingStore.delete(this, name))
                    }
                    "hasRecordAudioPermission" -> result.success(hasRecordAudioPermission())

                    // ---- 播放 ----
                    "playRecording" -> {
                        val path = call.arguments as? String ?: ""
                        result.success(PlaybackController.play(path))
                    }
                    "pausePlayback" -> {
                        PlaybackController.pause()
                        result.success(null)
                    }
                    "resumePlayback" -> result.success(PlaybackController.resume())
                    "stopPlayback" -> {
                        PlaybackController.stop()
                        result.success(null)
                    }
                    "seekPlayback" -> {
                        val ms = (call.arguments as? Number)?.toInt() ?: 0
                        PlaybackController.seekTo(ms)
                        result.success(null)
                    }
                    "getPlaybackStatus" -> result.success(playbackStatus())
                    else -> result.notImplemented()
                }
            }
    }

    private fun settingsMap(): Map<String, Any?> {
        val s = Prefs.load(this)
        return mapOf(
            "enabled" to s.enabled,
            "delay" to s.delaySeconds,
            "speakerphone" to s.speakerphone,
            "filterMode" to s.filterMode,
            "whitelist" to s.whitelist,
            "blacklist" to s.blacklist,
            "quietEnabled" to s.quietEnabled,
            "quietStart" to s.quietStartMinutes,
            "quietEnd" to s.quietEndMinutes,
            "autoRecord" to s.autoRecord
        )
    }

    private fun playbackStatus(): Map<String, Any?> {
        return mapOf(
            "isPlaying" to PlaybackController.isPlaying,
            "path" to PlaybackController.currentPath(),
            "position" to PlaybackController.positionMs(),
            "duration" to PlaybackController.durationMs()
        )
    }

    private fun hasRecordAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestRuntimePermissions() {
        val needed = mutableListOf(
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.READ_CALL_LOG,
            Manifest.permission.RECORD_AUDIO
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        val missing = needed.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), REQ_PERMISSIONS)
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val fullName = "$packageName/${AutoAnswerService::class.java.name}"
        val shortName = "$packageName/.AutoAnswerService"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.split(':').any {
            it.equals(fullName, ignoreCase = true) || it.equals(shortName, ignoreCase = true)
        }
    }

    companion object {
        private const val CHANNEL = "auto_answer/channel"
        private const val REQ_PERMISSIONS = 100
    }
}
