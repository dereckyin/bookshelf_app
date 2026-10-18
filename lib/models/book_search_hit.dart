import 'shelf_book.dart';

/// 跨書櫃搜尋結果
class BookSearchHit {
  const BookSearchHit({
    required this.book,
    required this.shelfId,
    required this.shelfName,
  });

  final ShelfBook book;
  final String shelfId;
  final String shelfName;
}
