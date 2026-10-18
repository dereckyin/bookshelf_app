import 'dart:typed_data';

import 'package:bookshelf_app/models/shelf_book.dart';
import 'package:bookshelf_app/services/excel_export_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildWorkbookBytes writes header and book rows', () {
    final books = [
      ShelfBook(
        id: '1',
        shelfId: 's',
        seq: 1,
        title: '保險法-案例式',
        price: 500,
        code13: '9789868253759',
        barcode: '978986825375920003',
        qty: 2,
        orgProdId: '11100123456',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    final bytes = ExcelExportService().buildWorkbookBytes(books);
    expect(bytes.length, greaterThan(1000));

    final excel = Excel.decodeBytes(Uint8List.fromList(bytes));
    final sheet = excel.tables.values.first;
    expect(sheet.rows.length, greaterThanOrEqualTo(2));

    final header = sheet.rows.first.map((c) => c?.value?.toString()).toList();
    expect(header.join(), contains('序號'));
    expect(header.join(), contains('書名'));
    expect(header.join(), contains('數量'));
    expect(header.join(), contains('條碼'));
    expect(header.join(), isNot(contains('13碼')));

    final row1 = sheet.rows[1].map((c) => c?.value?.toString() ?? '').toList();
    expect(row1.join(), contains('保險法'));
    expect(row1.join(), contains('978986825375920003'));
    expect(row1.join(), contains('2'));
  });
}
