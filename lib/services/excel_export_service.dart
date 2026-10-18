import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/shelf_book.dart';

class ExcelExportService {
  /// 產生 xlsx 並開啟系統分享。
  ///
  /// 注意：`excel` 套件對 sheet `rename`（尤其中文名）後寫入會變成空檔，
  /// 因此保留預設 Sheet1，並用 appendRow 寫入。
  Future<void> exportAndShare({
    required String shelfName,
    required List<ShelfBook> books,
  }) async {
    final bytes = buildWorkbookBytes(books);
    if (bytes.length < 1000) {
      throw StateError('產生的 Excel 檔異常（過小）');
    }

    final safeName = _safeFileName(shelfName);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '${safeName}_bookshelf.xlsx'));
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: '$shelfName 書櫃清單',
      text: '$shelfName 共 ${books.length} 本書',
    );
  }

  /// 產生 workbook bytes（供匯出與單元測試）。
  List<int> buildWorkbookBytes(List<ShelfBook> books) {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('序號'),
      TextCellValue('書名'),
      TextCellValue('價格'),
      TextCellValue('條碼'),
    ]);

    for (final book in books) {
      sheet.appendRow([
        TextCellValue('${book.seq}'),
        TextCellValue(book.title),
        TextCellValue(
          book.price == null ? '' : book.price!.toStringAsFixed(0),
        ),
        TextCellValue(book.barcode),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('無法產生 Excel 檔');
    }
    return bytes;
  }

  String _safeFileName(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (cleaned.isEmpty) return 'bookshelf';
    return cleaned;
  }
}
