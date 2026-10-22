import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/member_session.dart';

class WecollectAccountException implements Exception {
  WecollectAccountException(this.message);
  final String message;

  @override
  String toString() => message;
}

class WecollectAccountService {
  WecollectAccountService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  /// Email／密碼一次登入（doubleLogin）
  Future<MemberSession> doubleLogin({
    required String email,
    required String password,
  }) async {
    final uri = ApiConfig.accountUri('/taaze/doubleLogin');
    final response = await _client
        .post(
          uri,
          headers: ApiConfig.jsonHeaders,
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(_timeout);

    final body = _decodeMap(response.body);
    if (response.statusCode != 200 || body['success'] != true) {
      throw WecollectAccountException(
        body['message']?.toString() ?? '登入失敗',
      );
    }
    if (body['is_logon'] != true) {
      throw WecollectAccountException('登入失敗');
    }
    final suuid = body['suuid']?.toString() ?? '';
    final token = body['accessToken']?.toString() ?? '';
    if (suuid.isEmpty || token.isEmpty) {
      throw WecollectAccountException('登入回應不完整');
    }
    return MemberSession(
      suuid: suuid,
      accessToken: token,
      name: body['name']?.toString(),
    );
  }

  /// 憑網頁短碼換會員票
  Future<MemberSession> loginWithDeviceCode(String rawCode) async {
    final code = normalizeDeviceCode(rawCode);
    if (code.isEmpty) {
      throw WecollectAccountException('請輸入有效短碼');
    }
    final uri = ApiConfig.accountUri('/taaze/bookshelfDeviceLogin');
    final response = await _client
        .post(
          uri,
          headers: ApiConfig.jsonHeaders,
          body: jsonEncode({'code': code}),
        )
        .timeout(_timeout);

    final body = _decodeMap(response.body);
    if (response.statusCode == 404) {
      throw WecollectAccountException('此功能暫時無法使用');
    }
    if (response.statusCode != 200 || body['success'] != true) {
      throw WecollectAccountException(
        body['message']?.toString() ?? '短碼無效或已過期',
      );
    }
    final suuid = body['suuid']?.toString() ?? '';
    final token = body['accessToken']?.toString() ?? '';
    if (suuid.isEmpty || token.isEmpty) {
      throw WecollectAccountException('授權回應不完整');
    }
    return MemberSession(
      suuid: suuid,
      accessToken: token,
      name: body['name']?.toString(),
    );
  }

  /// 檢查票是否仍有效
  Future<bool> checkLogin(MemberSession session) async {
    final uri = ApiConfig.accountUri('/member/check/${session.suuid}');
    try {
      final response = await _client
          .post(
            uri,
            headers: ApiConfig.jsonHeaders,
            body: jsonEncode({'accessToken': session.accessToken}),
          )
          .timeout(_timeout);
      final body = _decodeMap(response.body);
      return response.statusCode == 200 &&
          body['success'] == true &&
          body['is_logon'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout(MemberSession session) async {
    final uri = ApiConfig.accountUri('/member/logout/${session.suuid}');
    try {
      await _client
          .post(
            uri,
            headers: ApiConfig.jsonHeaders,
            body: jsonEncode({'accessToken': session.accessToken}),
          )
          .timeout(_timeout);
    } catch (_) {
      // 本機仍清票
    }
  }

  static String normalizeDeviceCode(String raw) {
    var s = raw.trim();
    final lower = s.toLowerCase();
    const prefix = ApiConfig.deviceCodePrefix;
    if (lower.startsWith(prefix)) {
      s = s.substring(prefix.length);
    }
    return s.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }
}
