import 'dart:async';

import 'package:flutter/material.dart';

import 'native.dart';

/// 通话录音列表 + 播放页。
class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  List<RecordingItem> _items = [];
  bool _loaded = false;
  String? _playingPath;
  bool _isPlaying = false;
  int _position = 0;
  int _duration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _pollPlayback());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await NativeBridge.getRecordings();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loaded = true;
    });
  }

  Future<void> _pollPlayback() async {
    if (_playingPath == null) return;
    try {
      final s = await NativeBridge.getPlaybackStatus();
      if (!mounted) return;
      setState(() {
        _isPlaying = s.isPlaying;
        _position = s.position;
        _duration = s.duration;
      });
    } catch (_) {}
  }

  Future<void> _play(RecordingItem item) async {
    if (_playingPath == item.path && _isPlaying) {
      await NativeBridge.pausePlayback();
      setState(() => _isPlaying = false);
      return;
    }
    if (_playingPath == item.path && !_isPlaying) {
      final ok = await NativeBridge.resumePlayback();
      setState(() => _isPlaying = ok);
      return;
    }
    await NativeBridge.stopPlayback();
    final ok = await NativeBridge.playRecording(item.path);
    if (!mounted) return;
    setState(() {
      _playingPath = ok ? item.path : null;
      _isPlaying = ok;
      _position = 0;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('播放失败，文件可能已损坏')),
      );
    }
    await _pollPlayback();
  }

  Future<void> _stop() async {
    await NativeBridge.stopPlayback();
    if (!mounted) return;
    setState(() {
      _playingPath = null;
      _isPlaying = false;
      _position = 0;
      _duration = 0;
    });
  }

  Future<void> _delete(RecordingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除录音'),
        content: Text('确定删除「${item.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_playingPath == item.path) await _stop();
    await NativeBridge.deleteRecording(item.name);
    await _load();
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _fmtTime(int ms) {
    final total = (ms / 1000).floor();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtDate(DateTime t) {
    final d = t;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通话录音'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('暂无录音', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      SizedBox(height: 4),
                      Text(
                        '自动接听并开启录音后，通话录音会出现在这里',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_playingPath != null) _buildPlayerBar(),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final active = _playingPath == item.path;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: active
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Icon(
                                active && _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: active
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            title: Text(
                              item.number.isEmpty ? '未知号码' : item.number,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${_fmtDate(item.modified)}  ·  ${_fmtBytes(item.size)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(item),
                            ),
                            onTap: () => _play(item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPlayerBar() {
    final max = _duration > 0 ? _duration.toDouble() : 1.0;
    final value = _position.clamp(0, _duration).toDouble();
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    final item = _items.firstWhere(
                      (e) => e.path == _playingPath,
                      orElse: () => _items.first,
                    );
                    _play(item);
                  },
                  icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
                  iconSize: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                Expanded(
                  child: Slider(
                    value: value,
                    min: 0,
                    max: max,
                    onChanged: (v) {
                      setState(() => _position = v.round());
                      NativeBridge.seekPlayback(v.round());
                    },
                  ),
                ),
                Text(
                  '${_fmtTime(_position)} / ${_fmtTime(_duration)}',
                  style: const TextStyle(fontSize: 12),
                ),
                IconButton(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  tooltip: '停止',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
