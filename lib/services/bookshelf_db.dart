import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

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
      version: 1,
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
            created_at TEXT NOT NULL,
            FOREIGN KEY (shelf_id) REFERENCES shelves (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_books_shelf ON books (shelf_id, seq)',
        );
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<List<Shelf>> listShelves() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.*, COUNT(b.id) AS book_count
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

  Future<int> nextSeq(String shelfId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT MAX(seq) AS max_seq FROM books WHERE shelf_id = ?',
      [shelfId],
    );
    final maxSeq = rows.first['max_seq'] as int?;
    return (maxSeq ?? 0) + 1;
  }

  Future<bool> barcodeExists(String shelfId, String barcode) async {
    final db = await database;
    final rows = await db.query(
      'books',
      columns: ['id'],
      where: 'shelf_id = ? AND barcode = ?',
      whereArgs: [shelfId, barcode],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<ShelfBook> addBook({
    required String shelfId,
    required String barcode,
    String title = '',
    double? price,
    String? code13,
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
      },
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> deleteBook(String id) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
