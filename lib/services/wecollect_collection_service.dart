import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/member_session.dart';
import '../models/sync_diff.dart';

class WecollectCollectionException implements Exception {
  WecollectCollectionException(this.message);
  final String message;

  @override
  String toString() => message;
}

class WecollectCollectionService {
  WecollectCollectionService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 30);
  static const _pageSize = 50;

  /// 拉自己全部收藏（分頁）
  Future<List<RemoteCollection>> fetchAllCollections(
    MemberSession session,
  ) async {
    final all = <RemoteCollection>[];
    var page = 1;
    while (true) {
      final batch = await _fetchPage(session, page: page);
      if (batch.isEmpty) break;
      all.addAll(batch);
      if (batch.length < _pageSize) break;
      page++;
      if (page > 200) break;
    }
    return all;
  }

  Future<List<RemoteCollection>> _fetchPage(
    MemberSession session, {
    required int page,
  }) async {
    final uri = ApiConfig.socialUri(
      '/memberFunctions/collections/${session.suuid}',
      query: {
        'page': '$page',
        'size': '$_pageSize',
      },
    );
    final response = await _client
        .post(
          uri,
          headers: ApiConfig.jsonHeaders,
          body: jsonEncode({'memberAuth': session.memberAuth}),
        )
        .timeout(_timeout);

    final body = _decodeMap(response.body);
    if (response.statusCode != 200 || body['success'] != true) {
      throw WecollectCollectionException(
        body['message']?.toString() ?? '取得收藏失敗',
      );
    }
    final data = body['data'];
    if (data is! List) return [];
    final out = <RemoteCollection>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final c = RemoteCollection.fromJson(item);
        if (c.productinfoId.isNotEmpty || c.ean.isNotEmpty) {
          out.add(c);
        }
      } else if (item is Map) {
        final c = RemoteCollection.fromJson(Map<String, dynamic>.from(item));
        if (c.productinfoId.isNotEmpty || c.ean.isNotEmpty) {
          out.add(c);
        }
      }
    }
    return out;
  }

  /// 上傳一本書（只新增／upsert 收藏，不刪）
  Future<RemoteCollection?> collectByProdId({
    required MemberSession session,
    required String prodId,
    required List<String> category,
  }) async {
    final uri = ApiConfig.socialUri('/memberFunctions/collection/prod');
    final response = await _client
        .post(
          uri,
          headers: ApiConfig.jsonHeaders,
          body: jsonEncode({
            'memberAuth': session.memberAuth,
            'prod_id': prodId,
            'collection': {
              'owned': true,
              'open': '0',
              'status_flg': 'A',
              'category': category,
            },
          }),
        )
        .timeout(_timeout);

    final body = _decodeMap(response.body);
    if (response.statusCode != 200 || body['success'] != true) {
      throw WecollectCollectionException(
        body['message']?.toString() ?? '上傳收藏失敗',
      );
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return RemoteCollection.fromJson(data);
    }
    if (data is Map) {
      return RemoteCollection.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }
}
