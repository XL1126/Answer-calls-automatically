import 'package:flutter/material.dart';

import 'filter_page.dart';
import 'history_page.dart';
import 'native.dart';
import 'quiet_page.dart';
import 'recordings_page.dart';
import 'util.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  AppSettings _settings = AppSettings();
  bool _accessibilityEnabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _load() async {
    try {
      final s = await NativeBridge.getSettings();
      if (mounted) setState(() { _settings = s; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final v = await NativeBridge.isAccessibilityEnabled();
      if (mounted) setState(() => _accessibilityEnabled = v);
    } catch (_) {}
  }

  Future<void> _apply(void Function(AppSettings s) mutate, Future<void> Function() persist) async {
    setState(() => mutate(_settings));
    try { await persist(); } catch (_) {}
  }

  Future<void> _openFilter() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FilterPage(settings: _settings),
    ));
    _load();
  }

  Future<void> _openQuiet() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuietPage(settings: _settings),
    ));
    _load();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const HistoryPage(),
    ));
  }

  Future<void> _openRecordings() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const RecordingsPage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自动接电话'), centerTitle: true),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _StatusCard(enabled: _accessibilityEnabled, onRefresh: _refreshStatus),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '基本设置',
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('启用自动接听'),
                      subtitle: const Text('开启后，来电将按下方规则自动处理'),
                      value: _settings.enabled,
                      onChanged: (v) => _apply(
                        (s) => s.enabled = v,
                        () => NativeBridge.setEnabled(v),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('接听后开启免提'),
                      subtitle: const Text('自动接听后打开扬声器，录音也能录到双方声音'),
                      value: _settings.speakerphone,
                      onChanged: (v) => _apply(
                        (s) => s.speakerphone = v,
                        () => NativeBridge.setSpeakerphone(v),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('通话自动录音'),
                      subtitle: const Text('接通后自动录音，保存到应用内可随时播放'),
                      value: _settings.autoRecord,
                      onChanged: (v) => _apply(
                        (s) => s.autoRecord = v,
                        () => NativeBridge.setAutoRecord(v),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Text('接听延迟时间', style: TextStyle(fontSize: 16)),
                          const Spacer(),
                          Text(
                            '${_settings.delaySeconds} 秒',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      value: _settings.delaySeconds.toDouble(),
                      min: 0,
                      max: 30,
                      divisions: 30,
                      label: '${_settings.delaySeconds} 秒',
                      onChanged: (v) => _apply(
                        (s) => s.delaySeconds = v.round(),
                        () => NativeBridge.setDelay(v.round()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '接听规则',
                  children: [
                    _NavTile(
                      icon: Icons.filter_alt_outlined,
                      title: '号码过滤',
                      subtitle: _filterSummary(),
                      onTap: _openFilter,
                    ),
                    const Divider(height: 1),
                    _NavTile(
                      icon: Icons.schedule,
                      title: '定时接听时段',
                      subtitle: _quietSummary(),
                      onTap: _openQuiet,
                    ),
                    const Divider(height: 1),
                    _NavTile(
                      icon: Icons.history,
                      title: '通话记录',
                      subtitle: '查看最近接听 / 拒接 / 录音记录',
                      onTap: _openHistory,
                    ),
                    const Divider(height: 1),
                    _NavTile(
                      icon: Icons.graphic_eq,
                      title: '通话录音',
                      subtitle: '播放、管理已保存的通话录音',
                      onTap: _openRecordings,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '系统授权',
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: const Icon(Icons.phone_android),
                      title: const Text('电话与录音权限'),
                      subtitle: const Text('来电识别、接听与通话录音（必须）'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        try { await NativeBridge.requestPermission(); } catch (_) {}
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: const Icon(Icons.accessibility_new),
                      title: const Text('无障碍服务'),
                      subtitle: Text(_accessibilityEnabled ? '已开启' : '未开启，点击去开启'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        try { await NativeBridge.openAccessibility(); } catch (_) {}
                      },
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _filterSummary() {
    switch (_settings.filterMode) {
      case kFilterWhitelist:
        return '仅接听白名单号码（${_settings.whitelist.length} 个）';
      case kFilterBlacklistBlock:
        return '黑名单自动拒接（${_settings.blacklist.length} 个）';
      default:
        return '接听所有来电';
    }
  }

  String _quietSummary() {
    if (!_settings.quietEnabled) return '未启用，全天接听';
    return '${formatMinutes(_settings.quietStartMinutes)} - ${formatMinutes(_settings.quietEndMinutes)}';
  }
}

class _StatusCard extends StatelessWidget {
  final bool enabled;
  final Future<void> Function() onRefresh;

  const _StatusCard({required this.enabled, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.green : Colors.orange;
    return Card(
      color: color.withOpacity(0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(enabled ? Icons.check_circle : Icons.info,
                color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enabled ? '无障碍服务已开启' : '无障碍服务未开启',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '需要开启无障碍服务，应用才能在来电时自动执行接听或拒接操作。',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: '刷新状态',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}