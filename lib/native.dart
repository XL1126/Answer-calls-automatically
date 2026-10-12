import 'dart:convert';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('auto_answer/channel');

/// 过滤模式常量，与原生 Prefs.kt 保持一致。
const int kFilterAll = 0;
const int kFilterWhitelist = 1;
const int kFilterBlacklistBlock = 2;

/// 应用完整配置。
class AppSettings {
  bool enabled;
  int delaySeconds;
  bool speakerphone;
  int filterMode;
  List<String> whitelist;
  List<String> blacklist;
  bool quietEnabled;
  int quietStartMinutes;
  int quietEndMinutes;
  bool autoRecord;

  AppSettings({
    this.enabled = true,
    this.delaySeconds = 0,
    this.speakerphone = false,
    this.filterMode = kFilterAll,
    List<String>? whitelist,
    List<String>? blacklist,
    this.quietEnabled = false,
    this.quietStartMinutes = 0,
    this.quietEndMinutes = 0,
    this.autoRecord = true,
  })  : whitelist = whitelist ?? [],
        blacklist = blacklist ?? [];

  factory AppSettings.fromMap(Map<String, dynamic> m) {
    return AppSettings(
      enabled: m['enabled'] as bool? ?? true,
      delaySeconds: (m['delay'] as num? ?? 0).toInt(),
      speakerphone: m['speakerphone'] as bool? ?? false,
      filterMode: (m['filterMode'] as num? ?? kFilterAll).toInt(),
      whitelist: _toStringList(m['whitelist']),
      blacklist: _toStringList(m['blacklist']),
      quietEnabled: m['quietEnabled'] as bool? ?? false,
      quietStartMinutes: (m['quietStart'] as num? ?? 0).toInt(),
      quietEndMinutes: (m['quietEnd'] as num? ?? 0).toInt(),
      autoRecord: m['autoRecord'] as bool? ?? true,
    );
  }

  static List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

/// 单条通话记录。
class CallRecord {
  final String number;
  final String action;
  final DateTime time;

  CallRecord({required this.number, required this.action, required this.time});

  factory CallRecord.fromJson(Map<String, dynamic> m) {
    return CallRecord(
      number: m['number'] as String? ?? '未知号码',
      action: m['action'] as String? ?? '',
      time: DateTime.fromMillisecondsSinceEpoch((m['time'] as num? ?? 0).toInt()),
    );
  }
}

/// 通话录音文件。
class RecordingItem {
  final String name;
  final String path;
  final int size;
  final DateTime modified;
  final String number;

  RecordingItem({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
    required this.number,
  });

  factory RecordingItem.fromJson(Map<String, dynamic> m) {
    return RecordingItem(
      name: m['name'] as String? ?? '',
      path: m['path'] as String? ?? '',
      size: (m['size'] as num? ?? 0).toInt(),
      modified: DateTime.fromMillisecondsSinceEpoch((m['modified'] as num? ?? 0).toInt()),
      number: m['number'] as String? ?? '',
    );
  }
}

/// 播放状态。
class PlaybackStatus {
  final bool isPlaying;
  final String? path;
  final int position;
  final int duration;

  PlaybackStatus({
    required this.isPlaying,
    required this.path,
    required this.position,
    required this.duration,
  });

  factory PlaybackStatus.fromMap(Map<String, dynamic> m) {
    return PlaybackStatus(
      isPlaying: m['isPlaying'] as bool? ?? false,
      path: m['path'] as String?,
      position: (m['position'] as num? ?? 0).toInt(),
      duration: (m['duration'] as num? ?? 0).toInt(),
    );
  }
}

/// Dart 与 Android 原生层的通信桥接。
class NativeBridge {
  static Future<AppSettings> getSettings() async {
    final m = await _channel.invokeMapMethod<String, dynamic>('getSettings');
    if (m == null) return AppSettings();
    return AppSettings.fromMap(m);
  }

  static Future<void> setEnabled(bool value) =>
      _channel.invokeMethod('setEnabled', value);

  static Future<void> setDelay(int seconds) =>
      _channel.invokeMethod('setDelay', seconds);

  static Future<void> setSpeakerphone(bool value) =>
      _channel.invokeMethod('setSpeakerphone', value);

  static Future<void> setFilterMode(int mode) =>
      _channel.invokeMethod('setFilterMode', mode);

  static Future<void> setWhitelist(List<String> value) =>
      _channel.invokeMethod('setWhitelist', value);

  static Future<void> setBlacklist(List<String> value) =>
      _channel.invokeMethod('setBlacklist', value);

  static Future<void> setQuietHours({
    required bool enabled,
    required int start,
    required int end,
  }) =>
      _channel.invokeMethod('setQuietHours', {
        'enabled': enabled,
        'start': start,
        'end': end,
      });

  static Future<void> setAutoRecord(bool value) =>
      _channel.invokeMethod('setAutoRecord', value);

  static Future<List<CallRecord>> getHistory() async {
    final raw = await _channel.invokeMethod<String>('getHistory');
    if (raw == null || raw.isEmpty) return [];
    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      return parsed
          .map((e) => CallRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearHistory() => _channel.invokeMethod('clearHistory');

  static Future<void> requestPermission() =>
      _channel.invokeMethod('requestPermission');

  static Future<void> openAccessibility() =>
      _channel.invokeMethod('openAccessibility');

  static Future<bool> isAccessibilityEnabled() async =>
      await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  // ---- 录音 ----

  static Future<List<RecordingItem>> getRecordings() async {
    final raw = await _channel.invokeMethod<String>('getRecordings');
    if (raw == null || raw.isEmpty) return [];
    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      return parsed
          .map((e) => RecordingItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> deleteRecording(String name) async =>
      await _channel.invokeMethod<bool>('deleteRecording', name) ?? false;

  static Future<bool> hasRecordAudioPermission() async =>
      await _channel.invokeMethod<bool>('hasRecordAudioPermission') ?? false;

  // ---- 播放 ----

  static Future<bool> playRecording(String path) async =>
      await _channel.invokeMethod<bool>('playRecording', path) ?? false;

  static Future<void> pausePlayback() => _channel.invokeMethod('pausePlayback');

  static Future<bool> resumePlayback() async =>
      await _channel.invokeMethod<bool>('resumePlayback') ?? false;

  static Future<void> stopPlayback() => _channel.invokeMethod('stopPlayback');

  static Future<void> seekPlayback(int ms) =>
      _channel.invokeMethod('seekPlayback', ms);

  static Future<PlaybackStatus> getPlaybackStatus() async {
    final m = await _channel.invokeMapMethod<String, dynamic>('getPlaybackStatus');
    if (m == null) {
      return PlaybackStatus(isPlaying: false, path: null, position: 0, duration: 0);
    }
    return PlaybackStatus.fromMap(m);
  }
}
