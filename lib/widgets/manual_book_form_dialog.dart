import 'package:flutter/material.dart';

import '../models/book_condition.dart';

class ManualBookFormResult {
  const ManualBookFormResult({
    required this.title,
    this.price,
    required this.condition,
  });

  final String title;
  final double? price;
  final String condition;
}

/// 查無建檔：書名、台幣定價、書況
Future<ManualBookFormResult?> showManualBookFormDialog(
  BuildContext context, {
  required String barcode,
}) {
  return showDialog<ManualBookFormResult>(
    context: context,
    builder: (ctx) => _ManualBookFormDialog(barcode: barcode),
  );
}

/// 13 碼已查到：只選書況
Future<String?> showConditionOnlyDialog(
  BuildContext context, {
  required String title,
  String? priceLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _ConditionOnlyDialog(
      title: title,
      priceLabel: priceLabel,
    ),
  );
}

class _ManualBookFormDialog extends StatefulWidget {
  const _ManualBookFormDialog({required this.barcode});

  final String barcode;

  @override
  State<_ManualBookFormDialog> createState() => _ManualBookFormDialogState();
}

class _ManualBookFormDialogState extends State<_ManualBookFormDialog> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _condition = BookCondition.defaultValue;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入書名')),
      );
      return;
    }
    final priceText = _priceCtrl.text.trim();
    Navigator.pop(
      context,
      ManualBookFormResult(
        title: title,
        price: priceText.isEmpty ? null : double.tryParse(priceText),
        condition: _condition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('查無建檔'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '條碼 ${widget.barcode}\n資料庫找不到此書，請手動輸入：',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '書名',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '台幣定價',
                prefixText: 'NT\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              decoration: const InputDecoration(
                labelText: '書況',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in BookCondition.all)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) {
                if (v != null) _condition = v;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('確認加入'),
        ),
      ],
    );
  }
}

class _ConditionOnlyDialog extends StatefulWidget {
  const _ConditionOnlyDialog({
    required this.title,
    this.priceLabel,
  });

  final String title;
  final String? priceLabel;

  @override
  State<_ConditionOnlyDialog> createState() => _ConditionOnlyDialogState();
}

class _ConditionOnlyDialogState extends State<_ConditionOnlyDialog> {
  String _condition = BookCondition.defaultValue;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('選擇書況'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (widget.priceLabel != null && widget.priceLabel!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.priceLabel!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _condition,
            decoration: const InputDecoration(
              labelText: '書況',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final c in BookCondition.all)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) {
              if (v != null) _condition = v;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _condition),
          child: const Text('確認加入'),
        ),
      ],
    );
  }
}
