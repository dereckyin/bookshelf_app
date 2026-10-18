import 'package:bookshelf_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('shows shelf list title', (tester) async {
    await tester.pumpWidget(const BookshelfApp());
    // CircularProgressIndicator 會一直動畫，不能用 pumpAndSettle。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('我的書櫃'), findsOneWidget);
    expect(find.text('新增書櫃'), findsOneWidget);
  });
}
