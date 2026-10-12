package com.example.auto_answer

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

data class AnswerSettings(
    val enabled: Boolean,
    val delaySeconds: Int,
    val speakerphone: Boolean,
    val filterMode: Int,
    val whitelist: List<String>,
    val blacklist: List<String>,
    val quietEnabled: Boolean,
    val quietStartMinutes: Int,
    val quietEndMinutes: Int,
    val autoRecord: Boolean
)

object Prefs {
    const val NAME = "auto_answer_prefs"

    const val KEY_ENABLED = "enabled"
    const val KEY_DELAY = "delay_seconds"
    const val KEY_SPEAKER = "speakerphone"
    const val KEY_FILTER_MODE = "filter_mode"
    const val KEY_WHITELIST = "whitelist"
    const val KEY_BLACKLIST = "blacklist"
    const val KEY_QUIET_ENABLED = "quiet_enabled"
    const val KEY_QUIET_START = "quiet_start"
    const val KEY_QUIET_END = "quiet_end"
    const val KEY_HISTORY = "history"
    const val KEY_AUTO_RECORD = "auto_record"

    const val DEFAULT_DELAY = 0

    // 过滤模式
    const val FILTER_ALL = 0
    const val FILTER_WHITELIST = 1
    const val FILTER_BLACKLIST_BLOCK = 2

    fun sp(context: Context): SharedPreferences =
        context.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    fun load(context: Context): AnswerSettings {
        val p = sp(context)
        return AnswerSettings(
            enabled = p.getBoolean(KEY_ENABLED, true),
            delaySeconds = p.getInt(KEY_DELAY, DEFAULT_DELAY),
            speakerphone = p.getBoolean(KEY_SPEAKER, false),
            filterMode = p.getInt(KEY_FILTER_MODE, FILTER_ALL),
            whitelist = readList(p, KEY_WHITELIST),
            blacklist = readList(p, KEY_BLACKLIST),
            quietEnabled = p.getBoolean(KEY_QUIET_ENABLED, false),
            quietStartMinutes = p.getInt(KEY_QUIET_START, 0),
            quietEndMinutes = p.getInt(KEY_QUIET_END, 0),
            autoRecord = p.getBoolean(KEY_AUTO_RECORD, true)
        )
    }

    fun toStringList(value: Any?): List<String> {
        val list = value as? List<*> ?: return emptyList()
        return list.mapNotNull { it?.toString() }.filter { it.isNotBlank() }
    }

    fun writeList(p: SharedPreferences, key: String, value: List<String>) {
        val arr = JSONArray()
        value.forEach { arr.put(it) }
        p.edit().putString(key, arr.toString()).apply()
    }

    private fun readList(p: SharedPreferences, key: String): List<String> {
        val raw = p.getString(key, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getString(it) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    // ---- 通话记录 ----
    fun addHistory(context: Context, number: String, action: String) {
        val p = sp(context)
        val arr = readHistoryArray(p)
        val obj = JSONObject()
        obj.put("number", number)
        obj.put("action", action)
        obj.put("time", System.currentTimeMillis())
        arr.put(obj)
        while (arr.length() > 200) arr.remove(0)
        p.edit().putString(KEY_HISTORY, arr.toString()).apply()
    }

    fun getHistory(context: Context): JSONArray = readHistoryArray(sp(context))

    fun clearHistory(context: Context) {
        sp(context).edit().remove(KEY_HISTORY).apply()
    }

    private fun readHistoryArray(p: SharedPreferences): JSONArray {
        val raw = p.getString(KEY_HISTORY, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }
}