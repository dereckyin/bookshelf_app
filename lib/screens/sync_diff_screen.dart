import 'package:flutter/material.dart';

import '../models/member_session.dart';
import '../models/sync_diff.dart';
import '../services/sync_diff_service.dart';

/// 檢查差異後，上傳／匯入各需再確認一次
class SyncDiffScreen extends StatefulWidget {
  const SyncDiffScreen({super.key, required this.session});

  final MemberSession session;

  @override
  State<SyncDiffScreen> createState() => _SyncDiffScreenState();
}

class _SyncDiffScreenState extends State<SyncDiffScreen> {
  final _sync = SyncDiffService();
  SyncDiff? _diff;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final diff = await _sync.buildDiff(widget.session);
      if (!mounted) return;
      setState(() {
        _diff = diff;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmUpload() async {
    final diff = _diff;
    if (diff == null || diff.localOnly.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上傳到收藏'),
        content: Text(
          '將在收藏新增 ${diff.localOnly.length} 本（只新增，不改已有收藏）。確定？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認上傳'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final count = await _sync.uploadLocalOnly(
      session: widget.session,
      items: diff.localOnly,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已上傳 $count 本到收藏')),
    );
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmImport() async {
    final diff = _diff;
    if (diff == null || diff.remoteOnly.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('匯入手機'),
        content: Text(
          '將在手機新增 ${diff.remoteOnly.length} 本（不改已有的數量、書況、條碼）。確定？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認匯入'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final count = await _sync.importRemoteOnly(items: diff.remoteOnly);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已匯入 $count 本')),
    );
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final diff = _diff;
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步收藏'),
        actions: [
          IconButton(
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '重新檢查',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('重試'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '先看差異，再分別按確認。只會新增，不會覆蓋另一邊。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _section(
                      title: '步驟 1・只在手機（${diff!.localOnly.length}）',
                      actionLabel: '確認上傳',
                      onAction: diff.localOnly.isEmpty || _busy
                          ? null
                          : _confirmUpload,
                      children: diff.localOnly.isEmpty
                          ? [
                              const ListTile(
                                title: Text('沒有可上傳的書'),
                                subtitle: Text('對不到書目的不會出現在這裡'),
                              ),
                            ]
                          : [
                              for (final item in diff.localOnly)
                                ListTile(
                                  title: Text(
                                    item.book.title.isEmpty
                                        ? item.book.barcode
                                        : item.book.title,
                                  ),
                                  subtitle: Text(
                                    '書櫃：${item.shelfName.isEmpty ? '（未命名）' : item.shelfName}',
                                  ),
                                ),
                            ],
                    ),
                    const SizedBox(height: 16),
                    _section(
                      title: '步驟 2・只在收藏（${diff.remoteOnly.length}）',
                      actionLabel: '確認匯入',
                      onAction: diff.remoteOnly.isEmpty || _busy
                          ? null
                          : _confirmImport,
                      children: diff.remoteOnly.isEmpty
                          ? [const ListTile(title: Text('沒有可匯入的書'))]
                          : [
                              for (final item in diff.remoteOnly)
                                ListTile(
                                  title: Text(
                                    item.title.isEmpty ? item.ean : item.title,
                                  ),
                                  subtitle: Text(
                                    item.categories.isEmpty
                                        ? '會放進書櫃「冊格子」'
                                        : '書櫃：${item.categories.first}',
                                  ),
                                ),
                            ],
                    ),
                    const SizedBox(height: 16),
                    _section(
                      title: '兩邊都有（${diff.both.length}）・略過',
                      actionLabel: null,
                      onAction: null,
                      children: diff.both.isEmpty
                          ? [const ListTile(title: Text('沒有重疊的書'))]
                          : [
                              for (final item in diff.both)
                                ListTile(
                                  title: Text(
                                    item.title.isEmpty ? item.ean : item.title,
                                  ),
                                  subtitle: const Text('不更新、不刪除'),
                                ),
                            ],
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 24),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
    );
  }

  Widget _section({
    required String title,
    required String? actionLabel,
    required VoidCallback? onAction,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: actionLabel == null
                ? null
                : FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}
