import 'package:flutter/material.dart';

import 'native.dart';
import 'util.dart';

class QuietPage extends StatefulWidget {
  final AppSettings settings;

  const QuietPage({super.key, required this.settings});

  @override
  State<QuietPage> createState() => _QuietPageState();
}

class _QuietPageState extends State<QuietPage> {
  AppSettings get _s => widget.settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('定时接听时段')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: const Text('启用定时接听时段'),
              subtitle: const Text('仅在指定时间段内自动接听，其余时间不处理'),
              value: _s.quietEnabled,
              onChanged: (v) {
                setState(() => _s.quietEnabled = v);
                _persist();
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_s.quietEnabled) ...[
            _TimeCard(
              title: '开始时间',
              value: _s.quietStartMinutes,
              onChanged: (v) {
                setState(() => _s.quietStartMinutes = v.round());
                _persist();
              },
            ),
            const SizedBox(height: 16),
            _TimeCard(
              title: '结束时间',
              value: _s.quietEndMinutes,
              onChanged: (v) {
                setState(() => _s.quietEndMinutes = v.round());
                _persist();
              },
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('时段说明', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      '每天 ${formatMinutes(_s.quietStartMinutes)} 至 '
                      '${formatMinutes(_s.quietEndMinutes)} 内自动接听。'
                      '若开始时间晚于结束时间，则视为跨天时段（例如 22:00 至 06:00）。',
                      style: const TextStyle(fontSize: 13.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _persist() {
    NativeBridge.setQuietHours(
      enabled: _s.quietEnabled,
      start: _s.quietStartMinutes,
      end: _s.quietEndMinutes,
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String title;
  final int value;
  final ValueChanged<double> onChanged;

  const _TimeCard({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                const Spacer(),
                Text(
                  formatMinutes(value),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: 0,
              max: 1439,
              divisions: 287,
              label: formatMinutes(value),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}