import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/book_search_hit.dart';
import '../models/shelf.dart';
import '../models/shelf_book.dart';

class BookshelfDb {
  BookshelfDb._();
  static final BookshelfDb instance = BookshelfDb._();

  Database? _db;
  final _uuid = const Uuid();

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'bookshelf.db'),
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shelves (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE books (
            id TEXT PRIMARY KEY NOT NULL,
            shelf_id TEXT NOT NULL,
            seq INTEGER NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            price REAL,
            code13 TEXT,
            barcode TEXT NOT NULL,
            qty INTEGER NOT NULL DEFAULT 1,
            org_prod_id TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (shelf_id) REFERENCES shelves (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_books_shelf ON books (shelf_id, seq)',
        );
        await db.execute(
          'CREATE INDEX idx_books_barcode ON books (shelf_id, barcode)',
        );
        await db.execute(
          'CREATE INDEX idx_books_code13 ON books (shelf_id, code13)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE books ADD COLUMN qty INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_books_barcode ON books (shelf_id, barcode)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_books_code13 ON books (shelf_id, code13)',
          );
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE books ADD COLUMN org_prod_id TEXT');
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<List<Shelf>> listShelves() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.*, COALESCE(SUM(b.qty), 0) AS book_count
      FROM shelves s
      LEFT JOIN books b ON b.shelf_id = s.id
      GROUP BY s.id
      ORDER BY s.created_at ASC
    ''');
    return rows
        .map(
          (r) => Shelf.fromMap(
            r,
            bookCount: (r['book_count'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<Shelf> createShelf(String name) async {
    final db = await database;
    final shelf = Shelf(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    await db.insert('shelves', shelf.toMap());
    return shelf;
  }

  Future<void> renameShelf(String id, String name) async {
    final db = await database;
    await db.update(
      'shelves',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteShelf(String id) async {
    final db = await database;
    await db.delete('books', where: 'shelf_id = ?', whereArgs: [id]);
    await db.delete('shelves', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ShelfBook>> listBooks(String shelfId) async {
    final db = await database;
    final rows = await db.query(
      'books',
      where: 'shelf_id = ?',
      whereArgs: [shelfId],
      orderBy: 'seq ASC',
    );
    return rows.map(ShelfBook.fromMap).toList();
  }

  /// 跨所有書櫃搜尋書名／條碼／13 碼。
  Future<List<BookSearchHit>> searchAllBooks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final db = await database;
    final like = '%$q%';
    final rows = await db.rawQuery(
      '''
      SELECT b.*, s.id AS shelf_id_join, s.name AS shelf_name
      FROM books b
      INNER JOIN shelves s ON s.id = b.shelf_id
      WHERE b.title LIKE ? COLLATE NOCASE
         OR b.barcode LIKE ?
         OR IFNULL(b.code13, '') LIKE ?
      ORDER BY s.name ASC, b.seq ASC
      ''',
      [like, like, like],
    );

    return rows.map((r) {
      return BookSearchHit(
        book: ShelfBook.fromMap(r),
        shelfId: (r['shelf_id'] as String?) ?? (r['shelf_id_join'] as String),
        shelfName: (r['shelf_name'] as String?) ?? '',
      );
    }).toList();
  }

  Future<int> nextSeq(String shelfId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT MAX(seq) AS max_seq FROM books WHERE shelf_id = ?',
      [shelfId],
    );
    final maxSeq = rows.first['max_seq'] as int?;
    return (maxSeq ?? 0) + 1;
  }

  Future<ShelfBook?> findByBarcode(String shelfId, String barcode) async {
    final db = await database;
    final rows = await db.query(
      'books',
      where: 'shelf_id = ? AND barcode = ?',
      whereArgs: [shelfId, barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ShelfBook.fromMap(rows.first);
  }

  /// 找櫃內第一筆相同 13 碼（EAN／ISBN）的書。
  Future<ShelfBook?> findByCode13(String shelfId, String code13) async {
    final db = await database;
    final rows = await db.query(
      'books',
      where: 'shelf_id = ? AND code13 = ?',
      whereArgs: [shelfId, code13],
      orderBy: 'seq ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ShelfBook.fromMap(rows.first);
  }

  Future<ShelfBook> addBook({
    required String shelfId,
    required String barcode,
    String title = '',
    double? price,
    String? code13,
    String? orgProdId,
    int qty = 1,
  }) async {
    final db = await database;
    final seq = await nextSeq(shelfId);
    final book = ShelfBook(
      id: _uuid.v4(),
      shelfId: shelfId,
      seq: seq,
      title: title,
      price: price,
      code13: code13,
      barcode: barcode,
      orgProdId: orgProdId,
      qty: qty < 1 ? 1 : qty,
      createdAt: DateTime.now(),
    );
    await db.insert('books', book.toMap());
    return book;
  }

  Future<void> updateBook(ShelfBook book) async {
    final db = await database;
    await db.update(
      'books',
      {
        'title': book.title,
        'price': book.price,
        'code13': book.code13,
        'barcode': book.barcode,
        'qty': book.qty,
        'org_prod_id': book.orgProdId,
      },
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<ShelfBook> incrementQty(ShelfBook book, {int by = 1}) async {
    final updated = book.copyWith(qty: book.qty + by);
    await updateBook(updated);
    return updated;
  }

  Future<void> deleteBook(String id) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
