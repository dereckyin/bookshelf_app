import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/shelf_book.dart';

/// 匯出列：書櫃編號 + 書籍
class ExcelExportRow {
  const ExcelExportRow({
    required this.shelfName,
    required this.book,
  });

  final String shelfName;
  final ShelfBook book;
}

class ExcelExportService {
  /// 產生 xlsx 並開啟系統分享。
  ///
  /// 注意：`excel` 套件對 sheet `rename`（尤其中文名）後寫入會變成空檔，
  /// 因此保留預設 Sheet1，並用 appendRow 寫入。
  Future<void> exportAndShare({
    required String fileLabel,
    required List<ExcelExportRow> rows,
  }) async {
    final bytes = buildWorkbookBytes(rows);
    if (bytes.length < 1000) {
      throw StateError('產生的 Excel 檔異常（過小）');
    }

    final safeName = _safeFileName(fileLabel);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '${safeName}_bookshelf.xlsx'));
    await file.writeAsBytes(bytes, flush: true);

    final totalQty = rows.fold<int>(0, (sum, r) => sum + r.book.qty);
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: '$fileLabel 書櫃清單',
      text: '$fileLabel 共 $totalQty 本（${rows.length} 筆）',
    );
  }

  /// 單櫃快捷匯出。
  Future<void> exportShelfAndShare({
    required String shelfName,
    required List<ShelfBook> books,
  }) {
    return exportAndShare(
      fileLabel: shelfName,
      rows: [
        for (final b in books) ExcelExportRow(shelfName: shelfName, book: b),
      ],
    );
  }

  /// 產生 workbook bytes（供匯出與單元測試）。
  List<int> buildWorkbookBytes(List<ExcelExportRow> rows) {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('書櫃編號'),
      TextCellValue('序號'),
      TextCellValue('書名'),
      TextCellValue('價格'),
      TextCellValue('數量'),
      TextCellValue('書況'),
      TextCellValue('條碼'),
    ]);

    for (final row in rows) {
      final book = row.book;
      sheet.appendRow([
        TextCellValue(row.shelfName),
        TextCellValue('${book.seq}'),
        TextCellValue(book.title),
        TextCellValue(
          book.price == null ? '' : book.price!.toStringAsFixed(0),
        ),
        TextCellValue('${book.qty}'),
        TextCellValue(book.condition ?? ''),
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
