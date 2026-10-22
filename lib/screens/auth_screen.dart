import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../services/auth_session_service.dart';
import '../services/wecollect_account_service.dart';
import 'barcode_camera_scan_screen.dart';
import 'shelf_list_screen.dart';

/// 冊格子授權：瀏覽器登入為主；掃 QR／短碼收在備援區
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
    final scheme = theme.colorScheme;

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 40,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '冊格子書櫃',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '用手機瀏覽器登入冊格子後，再回到本 App 完成授權。\n書櫃資料仍保存在這支手機。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            _StepRow(
              index: 1,
              text: '開啟瀏覽器並登入冊格子',
              scheme: scheme,
            ),
            const SizedBox(height: 10),
            _StepRow(
              index: 2,
              text: '在網頁按「開啟冊格子書櫃」',
              scheme: scheme,
            ),
            const SizedBox(height: 10),
            _StepRow(
              index: 3,
              text: '回到 App，即可同步收藏',
              scheme: scheme,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _busy ? null : _openBrowserLogin,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.open_in_browser),
              label: Text(_busy ? '正在開啟…' : '用瀏覽器登入冊格子'),
            ),
            const SizedBox(height: 12),
            Text(
              '授權頁 wecollect.fun/user/bookshelf-link',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 36),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
                title: Text(
                  '無法開啟 App 時',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                children: [
                  Text(
                    '可改用下方短碼，或用另一台裝置顯示 QR 再掃描。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _scanQr,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('掃描授權 QR'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]'),
                      ),
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
                    onPressed:
                        _busy ? null : () => _loginCode(_codeCtrl.text),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('用短碼登入'),
                  ),
                ],
              ),
            ),
            if (widget.allowSkip) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _skip,
                  child: Text(
                    '先不登入，離線使用書櫃',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.text,
    required this.scheme,
  });

  final int index;
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }
}
