class Book {
  final int id;
  final String title;
  final String isbn;
  final int year;
  final int pages;
  final int publisherId;
  final List<int> authorIds;
  final List<int> genreIds;
  final int copiesTotal;
  final int copiesAvailable;
  final DateTime? deletedAt;

  const Book({
    required this.id,
    required this.title,
    required this.isbn,
    required this.year,
    required this.pages,
    required this.publisherId,
    required this.authorIds,
    required this.genreIds,
    required this.copiesTotal,
    required this.copiesAvailable,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Book copyWith({
    String? title,
    String? isbn,
    int? year,
    int? pages,
    int? publisherId,
    List<int>? authorIds,
    List<int>? genreIds,
    int? copiesTotal,
    int? copiesAvailable,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      isbn: isbn ?? this.isbn,
      year: year ?? this.year,
      pages: pages ?? this.pages,
      publisherId: publisherId ?? this.publisherId,
      authorIds: authorIds ?? this.authorIds,
      genreIds: genreIds ?? this.genreIds,
      copiesTotal: copiesTotal ?? this.copiesTotal,
      copiesAvailable: copiesAvailable ?? this.copiesAvailable,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isbn': isbn,
        'year': year,
        'pages': pages,
        'publisherId': publisherId,
        'authorIds': authorIds,
        'genreIds': genreIds,
        'copiesTotal': copiesTotal,
        'copiesAvailable': copiesAvailable,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  /// Тело запроса на создание и изменение. На запись уходят идентификаторы
  /// связей, а id, copiesAvailable и deletedAt сервер считает сам.
  Map<String, dynamic> toWriteJson() => {
        'title': title,
        'isbn': isbn,
        'year': year,
        'pages': pages,
        'publisherId': publisherId,
        'authorIds': authorIds,
        'genreIds': genreIds,
        'copiesTotal': copiesTotal,
      };

  /// Разбирает обе формы: «на запись» (publisherId, authorIds, genreIds)
  /// и «на чтение» из ответа сервера (publisher, authors, genres объектами).
  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        isbn: (j['isbn'] as String?) ?? '',
        year: (j['year'] as num?)?.toInt() ?? 0,
        pages: (j['pages'] as num?)?.toInt() ?? 0,
        publisherId:
            (j['publisherId'] as num?)?.toInt() ?? _idOf(j['publisher']) ?? 0,
        authorIds: _ids(j['authorIds'] ?? j['authors']),
        genreIds: _ids(j['genreIds'] ?? j['genres']),
        copiesTotal: (j['copiesTotal'] as num?)?.toInt() ?? 0,
        copiesAvailable: (j['copiesAvailable'] as num?)?.toInt() ?? 0,
        deletedAt: j['deletedAt'] == null
            ? null
            : DateTime.tryParse(j['deletedAt'] as String),
      );

  static int? _idOf(dynamic v) =>
      v is Map ? (v['id'] as num?)?.toInt() : (v as num?)?.toInt();

  /// Список идентификаторов из `[1, 2]` или из `[{"id": 1}, {"id": 2}]`.
  static List<int> _ids(dynamic v) =>
      v is List ? v.map(_idOf).whereType<int>().toList() : const [];
}
