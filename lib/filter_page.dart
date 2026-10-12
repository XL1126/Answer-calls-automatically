import 'package:flutter/material.dart';

import 'native.dart';

class FilterPage extends StatefulWidget {
  final AppSettings settings;

  const FilterPage({super.key, required this.settings});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  AppSettings get _s => widget.settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('号码过滤')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            children: [
              RadioListTile<int>(
                value: kFilterAll,
                groupValue: _s.filterMode,
                title: const Text('接听所有来电'),
                subtitle: const Text('不进行任何号码过滤'),
                onChanged: (v) => _setMode(v!),
              ),
              RadioListTile<int>(
                value: kFilterWhitelist,
                groupValue: _s.filterMode,
                title: const Text('仅接听白名单'),
                subtitle: const Text('只自动接听白名单内的号码'),
                onChanged: (v) => _setMode(v!),
              ),
              RadioListTile<int>(
                value: kFilterBlacklistBlock,
                groupValue: _s.filterMode,
                title: const Text('黑名单自动拒接'),
                subtitle: const Text('黑名单内的号码自动拒接，其余接听'),
                onChanged: (v) => _setMode(v!),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _NumberListSection(
            title: '白名单',
            subtitle: '仅接听白名单时生效，支持区号/前缀后缀匹配',
            numbers: _s.whitelist,
            onAdd: () => _addNumber(isWhite: true),
            onRemove: (n) => _removeNumber(n, isWhite: true),
          ),
          const SizedBox(height: 16),
          _NumberListSection(
            title: '黑名单',
            subtitle: '黑名单拒接模式下，来电会自动被拒接',
            numbers: _s.blacklist,
            onAdd: () => _addNumber(isWhite: false),
            onRemove: (n) => _removeNumber(n, isWhite: false),
          ),
        ],
      ),
    );
  }

  void _setMode(int v) {
    setState(() => _s.filterMode = v);
    NativeBridge.setFilterMode(v);
  }

  Future<void> _addNumber({required bool isWhite}) async {
    final controller = TextEditingController();
    final number = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isWhite ? '添加白名单号码' : '添加黑名单号码'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: '电话号码',
            hintText: '例如 13800138000',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (number == null || number.isEmpty) return;
    setState(() {
      final list = isWhite ? _s.whitelist : _s.blacklist;
      if (!list.contains(number)) list.add(number);
    });
    _persistList(isWhite);
  }

  void _removeNumber(String n, {required bool isWhite}) {
    setState(() {
      if (isWhite) {
        _s.whitelist.remove(n);
      } else {
        _s.blacklist.remove(n);
      }
    });
    _persistList(isWhite);
  }

  void _persistList(bool isWhite) {
    if (isWhite) {
      NativeBridge.setWhitelist(_s.whitelist);
    } else {
      NativeBridge.setBlacklist(_s.blacklist);
    }
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }
}

class _NumberListSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> numbers;
  final VoidCallback onAdd;
  final void Function(String) onRemove;

  const _NumberListSection({
    required this.title,
    required this.subtitle,
    required this.numbers,
    required this.onAdd,
    required this.onRemove,
  });

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
            ListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onAdd,
              ),
            ),
            if (numbers.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('暂无号码，点击右上角添加', style: TextStyle(color: Colors.grey)),
              )
            else
              ...numbers.map(
                (n) => ListTile(
                  dense: true,
                  title: Text(n, style: const TextStyle(fontFamily: 'monospace')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onRemove(n),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}