import 'package:flutter/material.dart';

import '../models/book_search_hit.dart';
import '../models/shelf.dart';
import '../services/bookshelf_db.dart';
import '../widgets/book_cover.dart';
import 'shelf_detail_screen.dart';

class ShelfListScreen extends StatefulWidget {
  const ShelfListScreen({super.key});

  @override
  State<ShelfListScreen> createState() => _ShelfListScreenState();
}

class _ShelfListScreenState extends State<ShelfListScreen> {
  final _db = BookshelfDb.instance;
  final _searchCtrl = TextEditingController();

  List<Shelf> _shelves = [];
  List<BookSearchHit> _hits = [];
  bool _loading = true;
  bool _searching = false;
  bool _searchBusy = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (!_searching) return;
    if (q.isEmpty) {
      setState(() => _hits = []);
      return;
    }
    _runSearch(q);
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searchBusy = true);
    final hits = await _db.searchAllBooks(query);
    if (!mounted || _searchCtrl.text.trim() != query) return;
    setState(() {
      _hits = hits;
      _searchBusy = false;
    });
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final shelves = await _db.listShelves();
    if (!mounted) return;
    setState(() {
      _shelves = shelves;
      _loading = false;
    });
    if (_searching && _searchCtrl.text.trim().isNotEmpty) {
      await _runSearch(_searchCtrl.text.trim());
    }
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtrl.clear();
        _hits = [];
      }
    });
  }

  Future<void> _createShelf() async {
    final name = await _promptName(title: '新增書櫃', hint: '例如：客廳、書房');
    if (name == null || name.isEmpty) return;
    await _db.createShelf(name);
    await _reload();
  }

  Future<void> _renameShelf(Shelf shelf) async {
    final name = await _promptName(
      title: '重新命名',
      hint: '書櫃名稱',
      initial: shelf.name,
    );
    if (name == null || name.isEmpty) return;
    await _db.renameShelf(shelf.id, name);
    await _reload();
  }

  Future<void> _deleteShelf(Shelf shelf) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除書櫃'),
        content: Text('確定刪除「${shelf.name}」？櫃內 ${shelf.bookCount} 本書也會一併刪除。'),
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
    await _db.deleteShelf(shelf.id);
    await _reload();
  }

  Future<String?> _promptName({
    required String title,
    required String hint,
    String? initial,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openShelf(Shelf shelf) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShelfDetailScreen(shelf: shelf),
      ),
    );
    await _reload();
  }

  Future<void> _openHit(BookSearchHit hit) async {
    Shelf? shelf;
    for (final s in _shelves) {
      if (s.id == hit.shelfId) {
        shelf = s;
        break;
      }
    }
    shelf ??= Shelf(
      id: hit.shelfId,
      name: hit.shelfName,
      createdAt: DateTime.now(),
    );
    await _openShelf(shelf);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final showResults = _searching && query.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜尋所有書櫃的書名或條碼',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
              )
            : const Text('我的書櫃'),
        actions: [
          IconButton(
            tooltip: _searching ? '關閉搜尋' : '搜尋全書',
            onPressed: _shelves.isEmpty && !_searching ? null : _toggleSearch,
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
        ],
      ),
      floatingActionButton: _searching
          ? null
          : FloatingActionButton.extended(
              onPressed: _createShelf,
              icon: const Icon(Icons.add),
              label: const Text('新增書櫃'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shelves.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shelves,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '還沒有書櫃\n依地點建立一個，再開始掃書',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                )
              : showResults
                  ? _buildSearchBody(query)
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: _shelves.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final shelf = _shelves[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${shelf.bookCount}'),
                              ),
                              title: Text(shelf.name),
                              subtitle: Text('${shelf.bookCount} 本書'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'rename') _renameShelf(shelf);
                                  if (value == 'delete') _deleteShelf(shelf);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text('重新命名'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('刪除'),
                                  ),
                                ],
                              ),
                              onTap: () => _openShelf(shelf),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildSearchBody(String query) {
    if (_searchBusy && _hits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '找不到符合「$query」的書',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _hits.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final hit = _hits[index];
        final book = hit.book;
        final priceText = book.price == null
            ? '—'
            : 'NT\$${book.price!.toStringAsFixed(0)}';
        return Card(
          child: ListTile(
            leading: BookCover(
              url: book.coverUrl,
              largeUrl: book.largeCoverUrl,
              title: book.title,
              seq: book.seq,
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
                '書櫃：${hit.shelfName}',
                '$priceText · 數量 ${book.qty}',
                '條碼 ${book.barcode}',
              ].join('\n'),
            ),
            isThreeLine: true,
            onTap: () => _openHit(hit),
          ),
        );
      },
    );
  }
}
