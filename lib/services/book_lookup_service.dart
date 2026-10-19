import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/book_condition.dart';
import '../models/shelf_book.dart';

class BookLookupException implements Exception {
  BookLookupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BookLookupService {
  BookLookupService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  /// 依條碼／ISBN 查書。回傳空列表表示查無資料（不是錯誤）。
  ///
  /// 讀冊 18 碼貼紙：優先打 `/book/lookup`（LOGCODE → 真實書況／售價）；
  /// 查無／逾時／錯誤一律再裁前 13 碼打 `/search/`，避免掃 18 碼完全失敗。
  Future<List<BookLookupResult>> lookup(String barcode) async {
    final q = barcode.trim();
    if (q.isEmpty) return [];

    final raw = q.replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(r'^\d{18}$').hasMatch(raw)) {
      try {
        final byLogcode = await lookupByLogcode(raw);
        if (byLogcode != null) {
          // LOGCODE 列常是 813… 無書封圖，用 ISBN 搜尋補正確 orgProdId
          return [await _withCatalogCover(byLogcode)];
        }
      } catch (_) {
        // lookup 慢或失敗時仍走 search，不阻斷掃碼
      }
    }

    final query = ean13FromBarcode(q) ?? q;
    return _search(query);
  }

  /// 若目前 orgProdId 無法當書封，改用 /search/ 的目錄版 orgProdId。
  Future<BookLookupResult> _withCatalogCover(BookLookupResult book) async {
    if (isCatalogCoverOrgId(book.orgProdId)) return book;
    final isbn = book.normalizedIsbn;
    if (isbn == null || isbn.isEmpty) return book;
    try {
      final results = await _search(isbn);
      final coverId = catalogCoverOrgIdFromSearch(results);
      if (coverId == null || coverId.isEmpty) return book;
      return BookLookupResult(
        id: book.id,
        title: book.title,
        orgProdId: coverId,
        price: book.price,
        isbn: book.isbn,
        author: book.author,
        imageUrl: book.imageUrl,
        condition: book.condition,
      );
    } catch (_) {
      return book;
    }
  }

  /// 依完整條碼查 PRODUCT（18 LOGCODE／11 PROD_ID／13 EAN）。
  /// 404／查無回傳 null；網路錯誤拋 [BookLookupException]。
  Future<BookLookupResult?> lookupByLogcode(String barcode) async {
    final raw = barcode.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.isEmpty) return null;

    final uri = ApiConfig.bookLookupUri(raw);
    late final http.Response response;
    try {
      // LOGCODE 查庫可能較慢；仍設上限，逾時由 caller fallback search
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw BookLookupException('網路連線失敗，請稍後再試');
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw BookLookupException('查詢失敗（${response.statusCode}）');
    }

    return parseBookLookupResponse(response.body);
  }

  Future<List<BookLookupResult>> _search(String q) async {
    final uri = ApiConfig.searchUri(q);
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } catch (e) {
      throw BookLookupException('網路連線失敗，請稍後再試');
    }

    if (response.statusCode != 200) {
      throw BookLookupException('查詢失敗（${response.statusCode}）');
    }

    return parseSearchResponse(response.body);
  }
}

/// 解析 `/book/lookup` JSON。
BookLookupResult? parseBookLookupResponse(String body) {
  final decoded = json.decode(body);
  if (decoded is! Map<String, dynamic>) return null;

  final title = decoded['title']?.toString() ?? '';
  final prodId = decoded['prodId']?.toString() ?? '';
  if (title.isEmpty && prodId.isEmpty) return null;

  double? parsePrice(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw != null) return double.tryParse(raw.toString());
    return null;
  }

  // 部分 LOGCODE 列 SALE_PRICE=0，改用 LIST_PRICE（定價）
  final salePrice = parsePrice(decoded['salePrice']);
  final listPrice = parsePrice(decoded['listPrice']);
  final price = (salePrice != null && salePrice > 0) ? salePrice : listPrice;

  final org = decoded['orgProdId']?.toString().trim();
  final isbn = decoded['isbn']?.toString().trim() ??
      decoded['eanCode']?.toString().trim();
  final rank = decoded['prodRank']?.toString();

  return BookLookupResult(
    id: prodId,
    title: title,
    orgProdId: (org == null || org.isEmpty) ? null : org,
    price: price,
    isbn: (isbn == null || isbn.isEmpty) ? null : isbn,
    condition: BookCondition.fromProdRank(rank),
  );
}

/// 解析搜尋 API JSON，方便單元測試。
List<BookLookupResult> parseSearchResponse(String body) {
  final decoded = json.decode(body);
  if (decoded is! Map<String, dynamic>) return [];
  if (decoded['success'] == false) return [];

  final data = decoded['data'];
  if (data is! List) return [];

  final results = <BookLookupResult>[];
  for (final item in data) {
    if (item is! Map<String, dynamic>) continue;
    final book = BookLookupResult.fromJson(item);
    if (book.title.isEmpty && book.id.isEmpty) continue;
    results.add(book);
  }
  return results;
}

/// 讀冊書封 media 通常用 111…／131… 目錄版 org_prod_id；
/// LOGCODE 列常見 813… 本身沒有書封圖。
bool isCatalogCoverOrgId(String? id) {
  final raw = id?.trim() ?? '';
  if (raw.isEmpty) return false;
  return raw.startsWith('111') || raw.startsWith('131');
}

/// 從搜尋結果挑可用的書封 orgProdId。
String? catalogCoverOrgIdFromSearch(List<BookLookupResult> results) {
  for (final r in results) {
    final org = r.orgProdId?.trim();
    if (isCatalogCoverOrgId(org)) return org;
  }
  for (final r in results) {
    if (isCatalogCoverOrgId(r.id)) return r.id;
  }
  return null;
}

/// 從掃到的條碼取出可用的 EAN-13（讀冊 18 碼取前 13）。
String? ean13FromBarcode(String scanned) {
  final raw = scanned.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\d+$').hasMatch(raw)) return null;
  if (raw.length == 13) return raw;
  if (raw.length == 18) return raw.substring(0, 13);
  return null;
}

/// 決定要寫入的 13 碼：優先 API isbn，其次掃到的 13／18 碼前綴。
String? resolveCode13({required String scanned, String? apiIsbn}) {
  final isbn = apiIsbn?.replaceAll(RegExp(r'[\s-]'), '');
  if (isbn != null && isbn.length == 13 && RegExp(r'^\d+$').hasMatch(isbn)) {
    return isbn;
  }
  return ean13FromBarcode(scanned);
}

/// 多筆搜尋結果時，依掃到的條碼自動挑一本，避免跳出選擇對話框。
///
/// 搜尋 API 不回傳 logcode／18 碼，因此以 18 碼前 13 位對 ISBN；
/// 若仍有多筆（同書新品／二手），優先選新品（id == orgProdId）。
BookLookupResult? pickBestMatch(
  List<BookLookupResult> results,
  String scanned,
) {
  if (results.isEmpty) return null;
  if (results.length == 1) return results.first;

  final code13 = ean13FromBarcode(scanned);
  var matched = results;
  if (code13 != null) {
    final byIsbn =
        results.where((r) => r.normalizedIsbn == code13).toList();
    if (byIsbn.isNotEmpty) matched = byIsbn;
  }
  if (matched.length == 1) return matched.first;

  final primary = matched.where((r) => r.isPrimaryEdition).toList();
  if (primary.isNotEmpty) return primary.first;

  // 讀冊新品 prod_id 常以 131 開頭，二手為 133
  final newer = matched.where((r) => r.id.startsWith('131')).toList();
  if (newer.isNotEmpty) return newer.first;

  return matched.first;
}
