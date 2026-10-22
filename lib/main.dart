import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/shelf_list_screen.dart';
import 'services/app_auth_link_service.dart';
import 'services/auth_session_service.dart';
import 'services/wecollect_account_service.dart';

final GlobalKey<NavigatorState> bookshelfNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  await AppAuthLinkService.instance.start();
  runApp(const BookshelfApp());
}

class BookshelfApp extends StatefulWidget {
  const BookshelfApp({super.key});

  @override
  State<BookshelfApp> createState() => _BookshelfAppState();
}

class _BookshelfAppState extends State<BookshelfApp> {
  StreamSubscription<String>? _authSub;
  bool _handlingAuth = false;

  @override
  void initState() {
    super.initState();
    _authSub = AppAuthLinkService.instance.codes.listen(_onAuthCode);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthCode(String code) async {
    if (_handlingAuth) return;
    _handlingAuth = true;
    final nav = bookshelfNavigatorKey.currentState;
    final messenger = bookshelfNavigatorKey.currentContext != null
        ? ScaffoldMessenger.maybeOf(bookshelfNavigatorKey.currentContext!)
        : null;
    try {
      final session =
          await WecollectAccountService().loginWithDeviceCode(code);
      await AuthSessionService.instance.save(session);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            session.name != null && session.name!.isNotEmpty
                ? '已登入：${session.name}'
                : '已登入冊格子',
          ),
        ),
      );
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
    } on WecollectAccountException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('授權失敗，請重新從瀏覽器開啟書櫃')),
      );
    } finally {
      _handlingAuth = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: bookshelfNavigatorKey,
      title: '冊格子書櫃',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ShelfListScreen(),
    );
  }
}
