import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../services/auth_session_service.dart';
import '../services/wecollect_account_service.dart';
import 'barcode_camera_scan_screen.dart';
import 'shelf_list_screen.dart';

/// 冊格子授權：瀏覽器登入回呼為主；掃 QR／短碼為備援
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.allowSkip = true});

  /// 未登入仍可離線使用書櫃
  final bool allowSkip;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _account = WecollectAccountService();
  final _session = AuthSessionService.instance;
  final _codeCtrl = TextEditingController();

  bool _busy = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session.revision.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.revision.removeListener(_onSessionChanged);
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    // 瀏覽器 deep link 登入成功後關閉本頁
    if (_busy || _finished) return;
    _session.load().then((s) {
      if (s != null && mounted && !_finished) {
        _finishOk();
      }
    });
  }

  Future<void> _finishOk() async {
    if (!mounted || _finished) return;
    _finished = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShelfListScreen()),
    );
  }

  Future<void> _skip() async {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShelfListScreen()),
    );
  }

  Future<void> _openBrowserLogin() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final uri = ApiConfig.bookshelfLinkUri(returnToApp: true);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        setState(() => _error = '無法開啟瀏覽器，請手動前往 wecollect.fun');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '無法開啟瀏覽器，請手動前往 wecollect.fun');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginCode(String raw) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _account.loginWithDeviceCode(raw);
      await _session.save(session);
      await _finishOk();
    } on WecollectAccountException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '網路異常，請稍後再試');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeCameraScanScreen(
          title: '掃描授權 QR',
          formats: [BarcodeFormat.qrCode],
          acceptRawQr: true,
        ),
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    _codeCtrl.text = WecollectAccountService.normalizeDeviceCode(code);
    await _loginCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('登入冊格子'),
        actions: [
          if (widget.allowSkip)
            TextButton(
              onPressed: _busy ? null : _skip,
              child: const Text('稍後'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('用瀏覽器登入', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '會開啟手機瀏覽器登入冊格子，完成後按「開啟冊格子書櫃」回到本 App。書櫃資料仍留在手機。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _openBrowserLogin,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('用瀏覽器登入冊格子'),
          ),
          const SizedBox(height: 8),
          Text(
            'wecollect.fun/user/bookshelf-link',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          Text('其他方式', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '若有第二螢幕可掃 QR，或手動輸入短碼。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _scanQr,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('掃描授權 QR'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(12),
            ],
            decoration: const InputDecoration(
              labelText: '短碼',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            enabled: !_busy,
            onSubmitted: (_) => _loginCode(_codeCtrl.text),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => _loginCode(_codeCtrl.text),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('用短碼登入'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
