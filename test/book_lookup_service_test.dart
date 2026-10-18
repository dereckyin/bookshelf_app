import 'package:bookshelf_app/models/shelf_book.dart';
import 'package:bookshelf_app/services/book_lookup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseSearchResponse maps title price isbn', () {
    const body = '''
{
  "success": true,
  "data": [
    {
      "id": "11100123456",
      "title": "保險法-案例式",
      "author": "作者",
      "price": 500,
      "isbn": "9789868253759"
    }
  ],
  "pagination": {
    "currentPage": 1,
    "pageSize": 5,
    "totalCount": 1,
    "totalPages": 1,
    "hasMore": false
  },
  "message": "搜尋成功"
}
''';
    final results = parseSearchResponse(body);
    expect(results, hasLength(1));
    expect(results.first.title, '保險法-案例式');
    expect(results.first.price, 500);
    expect(results.first.isbn, '9789868253759');
  });

  test('parseSearchResponse returns empty on failure or empty data', () {
    expect(parseSearchResponse('{"success":false}'), isEmpty);
    expect(
      parseSearchResponse(
        '{"success":true,"data":[],"pagination":{"currentPage":1,"pageSize":5,"totalCount":0,"totalPages":0,"hasMore":false},"message":"ok"}',
      ),
      isEmpty,
    );
  });

  test('ean13FromBarcode takes first 13 of TAAZE 18-digit sticker', () {
    expect(ean13FromBarcode('978986825375920003'), '9789868253759');
    expect(ean13FromBarcode('9789863152576'), '9789863152576');
    expect(ean13FromBarcode('12345'), isNull);
  });

  test('resolveCode13 prefers API isbn then scanned 13 or 18 prefix', () {
    expect(
      resolveCode13(scanned: '978986825375920003', apiIsbn: '978-986-825375-9'),
      '9789868253759',
    );
    expect(
      resolveCode13(scanned: '9789863152576', apiIsbn: null),
      '9789863152576',
    );
    expect(
      resolveCode13(scanned: '978986825375920003', apiIsbn: null),
      '9789868253759',
    );
  });

  test('pickBestMatch prefers primary edition matching 18-digit ISBN prefix', () {
    const scanned = '978027376452620053';
    final results = [
      const BookLookupResult(
        id: '13300019745',
        title: 'Digital Design International Version',
        orgProdId: '13100013557',
        price: 500,
        isbn: '9780273764526',
      ),
      const BookLookupResult(
        id: '13100013557',
        title: 'Digital Design International Version',
        orgProdId: '13100013557',
        price: 2925,
        isbn: '9780273764526',
      ),
      const BookLookupResult(
        id: '13300245840',
        title: 'Digital Design International Version',
        orgProdId: '13100013557',
        price: 2010,
        isbn: '9780273764526',
      ),
    ];
    final picked = pickBestMatch(results, scanned);
    expect(picked?.id, '13100013557');
    expect(picked?.price, 2925);
  });
}
