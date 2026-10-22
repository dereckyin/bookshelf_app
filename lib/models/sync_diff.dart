import 'shelf_book.dart';

/// 同步預覽用：只在手機／只在冊格子／兩邊都有
class SyncDiff {
  const SyncDiff({
    required this.localOnly,
    required this.remoteOnly,
    required this.both,
  });

  final List<LocalSyncItem> localOnly;
  final List<RemoteSyncItem> remoteOnly;
  final List<BothSyncItem> both;
}

class LocalSyncItem {
  const LocalSyncItem({
    required this.book,
    required this.shelfName,
    required this.prodId,
  });

  final ShelfBook book;
  final String shelfName;
  final String prodId;
}

class RemoteSyncItem {
  const RemoteSyncItem({
    required this.collectSuuid,
    required this.prodId,
    required this.title,
    required this.ean,
    required this.orgProdId,
    required this.categories,
  });

  final String collectSuuid;
  final String prodId;
  final String title;
  final String ean;
  final String? orgProdId;
  final List<String> categories;
}

class BothSyncItem {
  const BothSyncItem({
    required this.title,
    required this.prodId,
    required this.ean,
  });

  final String title;
  final String prodId;
  final String ean;
}

/// 冊格子收藏一列（API 原始欄位精簡）
class RemoteCollection {
  const RemoteCollection({
    required this.suuid,
    required this.productinfoId,
    required this.targetName,
    required this.ean,
    this.targetSuuid,
    this.category = const [],
    this.images,
  });

  final String suuid;
  final String productinfoId;
  final String targetName;
  final String ean;
  final String? targetSuuid;
  final List<String> category;
  final dynamic images;

  String? get orgProdId {
    final t = targetSuuid?.trim();
    if (t != null && t.isNotEmpty) return t;
    final p = productinfoId.trim();
    return p.isEmpty ? null : p;
  }

  factory RemoteCollection.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    List<String> categories = const [];
    if (cat is List) {
      categories = cat.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return RemoteCollection(
      suuid: json['suuid']?.toString() ?? '',
      productinfoId: json['productinfo_id']?.toString() ?? '',
      targetName: json['target_name']?.toString() ?? '',
      ean: json['ean']?.toString() ?? '',
      targetSuuid: json['target_suuid']?.toString(),
      category: categories,
      images: json['images'],
    );
  }
}
