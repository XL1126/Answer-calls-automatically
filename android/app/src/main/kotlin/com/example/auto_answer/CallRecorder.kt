package com.example.auto_answer

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 通话录音。
 *
 * Android 10+ 对第三方应用的 VOICE_CALL 音源限制较严，这里按可用性回退：
 * VOICE_CALL → VOICE_COMMUNICATION → MIC（MIC 需配合免提才能录到对方声音）。
 */
class CallRecorder(private val context: Context) {

    data class Result(val file: File, val source: Int)

    private var recorder: MediaRecorder? = null
    private var currentFile: File? = null
    private var currentSource: Int = -1

    val isRecording: Boolean get() = recorder != null

    fun start(number: String): Result? {
        stop()
        val dir = recordingDir(context)
        if (!dir.exists() && !dir.mkdirs()) return null

        val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val safeNumber = number.filter { it.isDigit() }.ifEmpty { "unknown" }
        val file = File(dir, "${stamp}_${safeNumber}.m4a")

        val sources = listOf(
            MediaRecorder.AudioSource.VOICE_CALL,
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.MIC,
        )
        for (source in sources) {
            try {
                val r = createRecorder(source, file)
                r.start()
                recorder = r
                currentFile = file
                currentSource = source
                return Result(file, source)
            } catch (_: Throwable) {
                try {
                    // 清理可能残留的半成品
                    file.delete()
                } catch (_: Throwable) {
                }
            }
        }
        currentFile = null
        currentSource = -1
        return null
    }

    fun stop(): File? {
        val r = recorder ?: return null
        recorder = null
        val file = currentFile
        currentFile = null
        try {
            r.stop()
        } catch (_: Throwable) {
            // stop 失败（如时长过短）时删除无效文件
            try {
                file?.delete()
            } catch (_: Throwable) {
            }
            return null
        }
        try {
            r.reset()
            r.release()
        } catch (_: Throwable) {
        }
        return file
    }

    /** 当前使用的音源，用于决定是否强制开免提。 */
    fun needsSpeakerForCapture(): Boolean = currentSource == MediaRecorder.AudioSource.MIC

    private fun createRecorder(source: Int, file: File): MediaRecorder {
        val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        r.setAudioSource(source)
        r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        r.setAudioEncodingBitRate(96_000)
        r.setAudioSamplingRate(44_100)
        r.setOutputFile(file.absolutePath)
        r.prepare()
        return r
    }

    companion object {
        fun recordingDir(context: Context): File =
            File(context.getExternalFilesDir(null), "call_recordings")
    }
}
