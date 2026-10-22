import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/member_session.dart';

class AuthSessionService {
  AuthSessionService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static final AuthSessionService instance = AuthSessionService();

  final FlutterSecureStorage _storage;

  /// deep link 登入後通知 UI 重抓 session
  final ValueNotifier<int> revision = ValueNotifier(0);

  static const _kSuuid = 'wecollect_suuid';
  static const _kToken = 'wecollect_access_token';
  static const _kName = 'wecollect_name';

  void notifyChanged() {
    revision.value++;
  }

  Future<MemberSession?> load() async {
    final suuid = await _storage.read(key: _kSuuid);
    final token = await _storage.read(key: _kToken);
    if (suuid == null ||
        suuid.isEmpty ||
        token == null ||
        token.isEmpty) {
      return null;
    }
    final name = await _storage.read(key: _kName);
    return MemberSession(suuid: suuid, accessToken: token, name: name);
  }

  Future<void> save(MemberSession session) async {
    await _storage.write(key: _kSuuid, value: session.suuid);
    await _storage.write(key: _kToken, value: session.accessToken);
    if (session.name != null && session.name!.isNotEmpty) {
      await _storage.write(key: _kName, value: session.name);
    }
    notifyChanged();
  }

  Future<void> clear() async {
    await _storage.delete(key: _kSuuid);
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kName);
    notifyChanged();
  }
}
