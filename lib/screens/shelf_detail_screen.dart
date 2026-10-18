import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/shelf.dart';
import '../models/shelf_book.dart';
import '../services/book_lookup_service.dart';
import '../services/bookshelf_db.dart';
import '../services/excel_export_service.dart';
import 'barcode_camera_scan_screen.dart';

class ShelfDetailScreen extends StatefulWidget {
  const ShelfDetailScreen({super.key, required this.shelf});

  final Shelf shelf;

  @override
  State<ShelfDetailScreen> createState() => _ShelfDetailScreenState();
}

class _ShelfDetailScreenState extends State<ShelfDetailScreen> {
  final _db = BookshelfDb.instance;
  final _lookup = BookLookupService();
  final _export = ExcelExportService();

  late Shelf _shelf;
  List<ShelfBook> _books = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _shelf = widget.shelf;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final books = await _db.listBooks(_shelf.id);
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeCameraScanScreen(title: '掃描書籍條碼'),
      ),
    );
    final trimmed = code?.trim() ?? '';
    if (trimmed.isEmpty) return;
    await _addByBarcode(trimmed);
  }

  Future<void> _manualInput() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手動輸入條碼'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 20,
          decoration: const InputDecoration(hintText: 'ISBN 13 碼或讀冊 18 碼'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('查詢'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = code?.trim() ?? '';
    if (trimmed.isEmpty) return;
    await _addByBarcode(trimmed);
  }

  Future<void> _addByBarcode(String barcode) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      List<BookLookupResult> results = [];
      try {
        results = await _lookup.lookup(barcode);
      } on BookLookupException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${e.message}，已先記錄條碼')),
          );
        }
      }

      BookLookupResult? chosen;
      if (results.isNotEmpty) {
        chosen = pickBestMatch(results, barcode);
        if (chosen == null) {
          chosen = await _pickResult(results);
          if (chosen == null) return;
        }
      }

      final code13 = resolveCode13(
        scanned: barcode,
        apiIsbn: chosen?.isbn,
      );
      final title = chosen?.title ?? '';
      final price = chosen?.price;

      // 1) 同一條碼（含讀冊 18 碼）已存在 → 問是否覆蓋
      final sameBarcode = await _db.findByBarcode(_shelf.id, barcode);
      if (sameBarcode != null) {
        if (!mounted) return;
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('條碼已存在'),
            content: Text(
              '條碼「$barcode」已在本櫃'
              '${sameBarcode.title.isEmpty ? '' : '（${sameBarcode.title}）'}。\n'
              '要覆蓋更新書名與價格嗎？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('覆蓋'),
              ),
            ],
          ),
        );
        if (overwrite != true) return;

        final updated = sameBarcode.copyWith(
          title: title.isEmpty ? sameBarcode.title : title,
          price: price ?? sameBarcode.price,
          code13: code13 ?? sameBarcode.code13,
        );
        await _db.updateBook(updated);
        HapticFeedback.mediumImpact();
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已覆蓋序號 ${updated.seq}')),
        );
        return;
      }

      // 2) 不同條碼但 13 碼（EAN）相同 → 問是否增加數量（買多本）
      if (code13 != null) {
        final sameEan = await _db.findByCode13(_shelf.id, code13);
        if (sameEan != null) {
          if (!mounted) return;
          final action = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('相同書籍'),
              content: Text(
                '本櫃已有相同 EAN（$code13）'
                '${sameEan.title.isEmpty ? '' : '：${sameEan.title}'}，'
                '目前數量 ${sameEan.qty}。\n'
                '要增加數量，或另外新增一筆？',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'new'),
                  child: const Text('另外新增'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'qty'),
                  child: const Text('增加數量'),
                ),
              ],
            ),
          );
          if (action == null) return;

          if (action == 'qty') {
            final updated = await _db.incrementQty(sameEan);
            HapticFeedback.mediumImpact();
            await _reload();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '已將「${updated.title.isEmpty ? code13 : updated.title}」'
                  '數量改為 ${updated.qty}',
                ),
              ),
            );
            return;
          }
          // action == 'new' → fall through to add
        }
      }

      final book = await _db.addBook(
        shelfId: _shelf.id,
        barcode: barcode,
        title: title,
        price: price,
        code13: code13,
      );

      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _books = [..._books, book];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            book.title.isEmpty
                ? '已新增序號 ${book.seq}（查無書名，可手動編輯）'
                : '已新增：${book.title}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<BookLookupResult?> _pickResult(List<BookLookupResult> results) {
    return showDialog<BookLookupResult>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('選擇書籍'),
        children: [
          for (final r in results)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.title),
                subtitle: Text(
                  [
                    if (r.author != null && r.author!.isNotEmpty) r.author!,
                    if (r.price != null) 'NT\$${r.price!.toStringAsFixed(0)}',
                    if (r.isbn != null) r.isbn!,
                  ].join(' · '),
                ),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Future<void> _editBook(ShelfBook book) async {
    final titleCtrl = TextEditingController(text: book.title);
    final priceCtrl = TextEditingController(
      text: book.price == null ? '' : book.price!.toStringAsFixed(0),
    );
    final qtyCtrl = TextEditingController(text: '${book.qty}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('編輯 · 序號 ${book.seq}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '書名'),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: '價格'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: '數量'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '條碼：${book.barcode}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (saved != true) {
      titleCtrl.dispose();
      priceCtrl.dispose();
      qtyCtrl.dispose();
      return;
    }

    final priceText = priceCtrl.text.trim();
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? book.qty;
    final updated = book.copyWith(
      title: titleCtrl.text.trim(),
      price: priceText.isEmpty ? null : double.tryParse(priceText),
      qty: qty < 1 ? 1 : qty,
      clearPrice: priceText.isEmpty,
    );
    titleCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();

    await _db.updateBook(updated);
    await _reload();
  }

  Future<void> _deleteBook(ShelfBook book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除書籍'),
        content: Text('確定刪除序號 ${book.seq}？\n${book.title.isEmpty ? book.barcode : book.title}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteBook(book.id);
    await _reload();
  }

  Future<void> _exportExcel() async {
    if (_books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('書櫃是空的，沒有可匯出的資料')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _export.exportAndShare(shelfName: _shelf.name, books: _books);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯出失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_shelf.name),
        actions: [
          IconButton(
            tooltip: '手動輸入',
            onPressed: _busy ? null : _manualInput,
            icon: const Icon(Icons.keyboard),
          ),
          IconButton(
            tooltip: '匯出 Excel',
            onPressed: _busy ? null : _exportExcel,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _scan,
        icon: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_scanner),
        label: Text(_busy ? '處理中…' : '掃描'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '還沒有書\n按右下角掃描，或用鍵盤手動輸入條碼',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: _books.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    final priceText = book.price == null
                        ? '—'
                        : 'NT\$${book.price!.toStringAsFixed(0)}';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${book.seq}'),
                        ),
                        title: Text(
                          book.title.isEmpty ? '(未查到書名)' : book.title,
                          style: book.title.isEmpty
                              ? TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontStyle: FontStyle.italic,
                                )
                              : null,
                        ),
                        subtitle: Text(
                          [
                            '$priceText · 數量 ${book.qty}',
                            '條碼 ${book.barcode}',
                          ].join('\n'),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _editBook(book);
                            if (value == 'delete') _deleteBook(book);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('編輯')),
                            PopupMenuItem(value: 'delete', child: Text('刪除')),
                          ],
                        ),
                        onTap: () => _editBook(book),
                      ),
                    );
                  },
                ),
    );
  }
}
