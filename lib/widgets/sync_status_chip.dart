import 'package:flutter/material.dart';

import '../models/shelf_book.dart';

/// 書本與冊格子「收藏」同步狀態標籤
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final String label;
    late final Color bg;
    late final Color fg;
    switch (status) {
      case SyncStatus.synced:
        label = '已在收藏';
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
      case SyncStatus.unlisted:
        label = '查無書目';
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
      case SyncStatus.pending:
        label = '未同步';
        bg = scheme.secondaryContainer;
        fg = scheme.onSecondaryContainer;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
