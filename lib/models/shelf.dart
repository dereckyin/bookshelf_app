class Shelf {
  const Shelf({
    required this.id,
    required this.name,
    required this.createdAt,
    this.bookCount = 0,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int bookCount;

  Shelf copyWith({String? name, int? bookCount}) {
    return Shelf(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      bookCount: bookCount ?? this.bookCount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Shelf.fromMap(Map<String, Object?> map, {int bookCount = 0}) {
    return Shelf(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      bookCount: bookCount,
    );
  }
}
