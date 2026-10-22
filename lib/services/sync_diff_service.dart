import '../models/member_session.dart';
import '../models/shelf_book.dart';
import '../models/sync_diff.dart';
import 'book_lookup_service.dart';
import 'bookshelf_db.dart';
import 'wecollect_collection_service.dart';

class SyncDiffService {
  SyncDiffService({
    BookshelfDb? db,
    BookLookupService? lookup,
    WecollectCollectionService? collection,
  })  : _db = db ?? BookshelfDb.instance,
        _lookup = lookup ?? BookLookupService(),
        _collection = collection ?? WecollectCollectionService();

  final BookshelfDb _db;
  final BookLookupService _lookup;
  final WecollectCollectionService _collection;

  /// 從收藏匯入時的預設書櫃（不把收藏分類拆成手機書櫃）
  static const defaultImportShelfName = '收藏';

  Future<SyncDiff> buildDiff(MemberSession session) async {
    final shelves = await _db.listShelves();
    final shelfById = {for (final s in shelves) s.id: s};

    final localBooks = <ShelfBook>[];
    for (final s in shelves) {
      localBooks.addAll(await _db.listBooks(s.id));
    }

    final remote = await _collection.fetchAllCollections(session);

    // 同時用 prodId／EAN 建索引，避免 id 格式不一致就誤判成「只在一邊」
    final remoteByProd = <String, RemoteCollection>{};
    final remoteByEan = <String, RemoteCollection>{};
    for (final c in remote) {
      final p = c.productinfoId.trim();
      if (p.isNotEmpty) remoteByProd.putIfAbsent(p, () => c);
      final e = _normalizeEan(c.ean);
      if (e != null) remoteByEan.putIfAbsent(e, () => c);
    }

    final localOnly = <LocalSyncItem>[];
    final both = <BothSyncItem>[];
    final matchedRemoteSuuids = <String>{};

    for (final book in localBooks) {
      final shelfName = shelfById[book.shelfId]?.name ?? '';
      var prodId = book.prodId?.trim();
      if (prodId == null || prodId.isEmpty) {
        prodId = await _resolveProdId(book);
        if (prodId != null) {
          await _db.updateBook(
            book.copyWith(prodId: prodId, syncStatus: book.syncStatus),
          );
        }
      }

      final remoteHit = _matchRemote(
        prodId: prodId,
        ean: book.code13 ?? book.barcode,
        byProd: remoteByProd,
        byEan: remoteByEan,
      );
      if (remoteHit != null) {
        matchedRemoteSuuids.add(remoteHit.suuid);
        if (book.syncStatus != SyncStatus.synced ||
            book.collectSuuid != remoteHit.suuid) {
          await _db.updateBook(
            book.copyWith(
              prodId: remoteHit.productinfoId.isNotEmpty
                  ? remoteHit.productinfoId
                  : prodId,
              collectSuuid: remoteHit.suuid,
              syncStatus: SyncStatus.synced,
            ),
          );
        }
        both.add(
          BothSyncItem(
            title: book.title.isNotEmpty ? book.title : remoteHit.targetName,
            prodId: remoteHit.productinfoId,
            ean: remoteHit.ean.isNotEmpty
                ? remoteHit.ean
                : (book.code13 ?? ''),
          ),
        );
        continue;
      }

      if (prodId == null || prodId.isEmpty) {
        // 對不到書目：不算可上傳，仍標 unlisted
        if (book.syncStatus != SyncStatus.unlisted) {
          await _db.updateBook(book.copyWith(syncStatus: SyncStatus.unlisted));
        }
        continue;
      }

      localOnly.add(
        LocalSyncItem(book: book, shelfName: shelfName, prodId: prodId),
      );
    }

    final remoteOnly = <RemoteSyncItem>[];
    final seenRemote = <String>{};
    for (final c in remote) {
      if (matchedRemoteSuuids.contains(c.suuid)) continue;
      if (!seenRemote.add(c.suuid)) continue;
      final already = localBooks.any(
        (b) => b.collectSuuid != null && b.collectSuuid == c.suuid,
      );
      if (already) continue;

      remoteOnly.add(
        RemoteSyncItem(
          collectSuuid: c.suuid,
          prodId: c.productinfoId,
          title: c.targetName,
          ean: c.ean,
          orgProdId: c.orgProdId,
          categories: c.category,
        ),
      );
    }

    return SyncDiff(
      localOnly: localOnly,
      remoteOnly: remoteOnly,
      both: both,
    );
  }

  Future<int> uploadLocalOnly({
    required MemberSession session,
    required List<LocalSyncItem> items,
  }) async {
    var ok = 0;
    for (final item in items) {
      try {
        // 不寫入 category：手機書櫃 ≠ 收藏分類；寫入會蓋掉網站既有分類
        final created = await _collection.collectByProdId(
          session: session,
          prodId: item.prodId,
          category: const [],
          includeCategory: false,
        );
        final updated = item.book.copyWith(
          prodId: item.prodId,
          collectSuuid: created?.suuid,
          syncStatus: SyncStatus.synced,
        );
        await _db.updateBook(updated);
        ok++;
      } catch (_) {
        // 單本失敗不中斷
      }
    }
    return ok;
  }

  Future<int> importRemoteOnly({
    required List<RemoteSyncItem> items,
  }) async {
    var ok = 0;
    final shelves = await _db.listShelves();
    final byName = {for (final s in shelves) s.name: s};

    var shelf = byName[defaultImportShelfName];
    if (shelf == null) {
      shelf = await _db.createShelf(defaultImportShelfName);
      byName[defaultImportShelfName] = shelf;
    }

    for (final item in items) {
      try {
        final barcode = item.ean.isNotEmpty ? item.ean : item.prodId;
        final existing = await _db.findByProdIdOrEan(
          prodId: item.prodId,
          ean: item.ean,
        );
        if (existing != null) {
          if (existing.syncStatus != SyncStatus.synced ||
              existing.collectSuuid != item.collectSuuid) {
            await _db.updateBook(
              existing.copyWith(
                prodId: item.prodId,
                collectSuuid: item.collectSuuid,
                syncStatus: SyncStatus.synced,
              ),
            );
          }
          continue;
        }

        await _db.addBook(
          shelfId: shelf.id,
          barcode: barcode,
          title: item.title,
          code13: item.ean.length == 13 ? item.ean : null,
          orgProdId: item.orgProdId,
          prodId: item.prodId,
          collectSuuid: item.collectSuuid,
          syncStatus: SyncStatus.synced,
        );
        ok++;
      } catch (_) {}
    }
    return ok;
  }

  RemoteCollection? _matchRemote({
    required String? prodId,
    required String ean,
    required Map<String, RemoteCollection> byProd,
    required Map<String, RemoteCollection> byEan,
  }) {
    final p = prodId?.trim() ?? '';
    if (p.isNotEmpty) {
      final hit = byProd[p];
      if (hit != null) return hit;
    }
    final e = _normalizeEan(ean);
    if (e != null) return byEan[e];
    return null;
  }

  String? _normalizeEan(String? raw) {
    final e = (raw ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (e.length >= 10 && RegExp(r'^[0-9]+$').hasMatch(e)) return e;
    return null;
  }

  Future<String?> _resolveProdId(ShelfBook book) async {
    final existing = book.prodId?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final org = book.orgProdId?.trim();
    // 目錄版 org 常可當 productinfo_id
    if (org != null &&
        org.isNotEmpty &&
        (org.startsWith('111') || org.startsWith('131'))) {
      return org;
    }

    final q = book.code13?.trim().isNotEmpty == true
        ? book.code13!.trim()
        : book.barcode.trim();
    if (q.isEmpty) return null;
    try {
      final results = await _lookup.lookup(q);
      if (results.isEmpty) return null;
      final best = results.first;
      final id = best.orgProdId?.trim().isNotEmpty == true
          ? best.orgProdId!.trim()
          : best.id.trim();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

}
