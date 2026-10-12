package com.example.auto_answer

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** 录音文件管理：扫描目录、删除、读取元数据。 */
object RecordingStore {

    fun list(context: Context): JSONArray {
        val dir = CallRecorder.recordingDir(context)
        val files = dir.listFiles { f -> f.isFile && f.extension.equals("m4a", true) }
            ?: emptyArray()
        val arr = JSONArray()
        files.sortedByDescending { it.lastModified() }.forEach { f ->
            arr.put(toJson(f))
        }
        return arr
    }

    fun delete(context: Context, name: String): Boolean {
        val target = resolve(context, name) ?: return false
        return target.delete()
    }

    fun resolve(context: Context, name: String): File? {
        // 禁止路径穿越
        if (name.isBlank() || name.contains('/') || name.contains('\\') || name.contains("..")) {
            return null
        }
        val file = File(CallRecorder.recordingDir(context), name)
        if (!file.isFile) return null
        return file
    }

    fun toJson(file: File): JSONObject {
        val obj = JSONObject()
        obj.put("name", file.name)
        obj.put("path", file.absolutePath)
        obj.put("size", file.length())
        obj.put("modified", file.lastModified())
        obj.put("number", extractNumber(file.name))
        return obj
    }

    private fun extractNumber(name: String): String {
        // 文件名格式：yyyyMMdd_HHmmss_number.m4a
        val base = name.substringBeforeLast('.')
        val parts = base.split('_')
        return if (parts.size >= 3) parts.subList(2, parts.size).joinToString("_") else ""
    }
}
