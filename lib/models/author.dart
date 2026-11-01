/// Автор. Поля совпадают с контрактом учебного API (раздел 4):
/// `{ id, fullName, birthYear, country, deletedAt }`.
class Author {
  final int id;

  /// Фамилия и инициалы одной строкой, например «Толстой Л. Н.».
  final String fullName;
  final String country;
  final int? birthYear;
  final DateTime? deletedAt;

  const Author({
    required this.id,
    required this.fullName,
    this.country = '',
    this.birthYear,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// Фамилия — первое слово полного имени, по ней удобно сортировать.
  String get lastName => fullName.split(' ').first;

  Author copyWith({
    String? fullName,
    String? country,
    Object? birthYear = _unset,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Author(
      id: id,
      fullName: fullName ?? this.fullName,
      country: country ?? this.country,
      birthYear: birthYear == _unset ? this.birthYear : birthYear as int?,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  static const _unset = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'country': country,
        'birthYear': birthYear,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Author.fromJson(Map<String, dynamic> j) => Author(
        id: (j['id'] as num?)?.toInt() ?? 0,
        fullName: _readFullName(j),
        country: (j['country'] as String?) ?? '',
        birthYear: (j['birthYear'] as num?)?.toInt(),
        deletedAt: j['deletedAt'] == null
            ? null
            : DateTime.tryParse(j['deletedAt'] as String),
      );

  /// Миграция со старого формата, где имя хранилось двумя полями
  /// `firstName` и `lastName`: такие записи могли остаться в localStorage.
  static String _readFullName(Map<String, dynamic> j) {
    final full = j['fullName'];
    if (full is String && full.isNotEmpty) return full;
    final last = (j['lastName'] as String?) ?? '';
    final first = (j['firstName'] as String?) ?? '';
    return [last, if (first.isNotEmpty) '${first[0]}.']
        .where((s) => s.isNotEmpty)
        .join(' ');
  }
}
