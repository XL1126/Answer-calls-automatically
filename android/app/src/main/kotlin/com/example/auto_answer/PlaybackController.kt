package com.example.auto_answer

import android.media.MediaPlayer
import java.io.File

/** 应用内录音播放器（单例）。 */
object PlaybackController {

    private var player: MediaPlayer? = null
    private var currentPath: String? = null

    val isPlaying: Boolean
        get() = try {
            player?.isPlaying == true
        } catch (_: Throwable) {
            false
        }

    fun play(path: String): Boolean {
        return try {
            if (currentPath == path && player != null) {
                if (player?.isPlaying == true) return true
                player?.start()
                return true
            }
            stop()
            val f = File(path)
            if (!f.isFile) return false
            val mp = MediaPlayer()
            mp.setDataSource(path)
            mp.setOnCompletionListener {
                try {
                    it.seekTo(0)
                } catch (_: Throwable) {
                }
            }
            mp.prepare()
            mp.start()
            player = mp
            currentPath = path
            true
        } catch (_: Throwable) {
            stop()
            false
        }
    }

    fun pause() {
        try {
            if (player?.isPlaying == true) player?.pause()
        } catch (_: Throwable) {
        }
    }

    fun resume(): Boolean {
        return try {
            if (player == null) return false
            if (player?.isPlaying == false) player?.start()
            player?.isPlaying == true
        } catch (_: Throwable) {
            false
        }
    }

    fun stop() {
        try {
            player?.stop()
        } catch (_: Throwable) {
        }
        try {
            player?.release()
        } catch (_: Throwable) {
        }
        player = null
        currentPath = null
    }

    fun seekTo(ms: Int) {
        try {
            player?.seekTo(ms)
        } catch (_: Throwable) {
        }
    }

    fun positionMs(): Int = try {
        player?.currentPosition ?: 0
    } catch (_: Throwable) {
        0
    }

    fun durationMs(): Int = try {
        player?.duration ?: 0
    } catch (_: Throwable) {
        0
    }

    fun currentPath(): String? = currentPath
}
