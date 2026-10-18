import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
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
  /// 讀冊 18 碼貼紙：查詢一律裁成前 13 碼（EAN／ISBN）打 `/search/`；
  /// 畫面上仍保留掃到的完整 18 碼。
  Future<List<BookLookupResult>> lookup(String barcode) async {
    final q = barcode.trim();
    if (q.isEmpty) return [];

    final query = ean13FromBarcode(q) ?? q;
    return _search(query);
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
