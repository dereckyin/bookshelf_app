class ShelfBook {
  const ShelfBook({
    required this.id,
    required this.shelfId,
    required this.seq,
    required this.title,
    this.price,
    this.code13,
    required this.barcode,
    required this.createdAt,
  });

  final String id;
  final String shelfId;
  final int seq;
  final String title;
  final double? price;
  final String? code13;
  final String barcode;
  final DateTime createdAt;

  ShelfBook copyWith({
    String? title,
    double? price,
    String? code13,
    bool clearPrice = false,
    bool clearCode13 = false,
  }) {
    return ShelfBook(
      id: id,
      shelfId: shelfId,
      seq: seq,
      title: title ?? this.title,
      price: clearPrice ? null : (price ?? this.price),
      code13: clearCode13 ? null : (code13 ?? this.code13),
      barcode: barcode,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'shelf_id': shelfId,
      'seq': seq,
      'title': title,
      'price': price,
      'code13': code13,
      'barcode': barcode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ShelfBook.fromMap(Map<String, Object?> map) {
    return ShelfBook(
      id: map['id'] as String,
      shelfId: map['shelf_id'] as String,
      seq: map['seq'] as int,
      title: (map['title'] as String?) ?? '',
      price: (map['price'] as num?)?.toDouble(),
      code13: map['code13'] as String?,
      barcode: map['barcode'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// API 搜尋結果候選
class BookLookupResult {
  const BookLookupResult({
    required this.id,
    required this.title,
    this.orgProdId,
    this.price,
    this.isbn,
    this.author,
  });

  final String id;
  final String title;
  final String? orgProdId;
  final double? price;
  final String? isbn;
  final String? author;

  /// 正規化後的 ISBN／EAN（去空白與連字號）
  String? get normalizedIsbn {
    final raw = isbn?.replaceAll(RegExp(r'[\s-]'), '');
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  /// 讀冊新品通常 prod_id == org_prod_id（二手為不同 133… id）
  bool get isPrimaryEdition =>
      orgProdId != null && orgProdId!.isNotEmpty && id == orgProdId;

  factory BookLookupResult.fromJson(Map<String, dynamic> json) {
    final priceRaw = json['price'];
    double? price;
    if (priceRaw is num) {
      price = priceRaw.toDouble();
    } else if (priceRaw != null) {
      price = double.tryParse(priceRaw.toString());
    }
    final isbn = json['isbn']?.toString().trim();
    final org = json['orgProdId']?.toString().trim();
    return BookLookupResult(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      orgProdId: (org == null || org.isEmpty) ? null : org,
      price: price,
      isbn: (isbn == null || isbn.isEmpty) ? null : isbn,
      author: json['author']?.toString(),
    );
  }
}
