import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

/// 監聽 wecollect-bookshelf://auth?code= 回呼
class AppAuthLinkService {
  AppAuthLinkService._();
  static final AppAuthLinkService instance = AppAuthLinkService._();

  final _appLinks = AppLinks();
  final _codes = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _sub;
  bool _started = false;
  String? _lastEmitted;

  Stream<String> get codes => _codes.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final initial = await _appLinks.getInitialLink();
      _emitFromUri(initial);
    } catch (e) {
      debugPrint('AppAuthLink initial: $e');
    }
    _sub = _appLinks.uriLinkStream.listen(
      _emitFromUri,
      onError: (Object e) => debugPrint('AppAuthLink stream: $e'),
    );
  }

  void _emitFromUri(Uri? uri) {
    if (uri == null) return;
    final code = ApiConfig.deviceCodeFromAuthUri(uri);
    if (code == null || code.isEmpty) return;
    if (_lastEmitted == code) return;
    _lastEmitted = code;
    _codes.add(code);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
