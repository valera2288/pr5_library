/// Издательство. Поля по контракту API:
/// `{ id, name, city, foundedYear, deletedAt }`.
class Publisher {
  final int id;
  final String name;
  final String city;
  final int? foundedYear;
  final DateTime? deletedAt;

  const Publisher({
    required this.id,
    required this.name,
    this.city = '',
    this.foundedYear,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Publisher copyWith({
    String? name,
    String? city,
    Object? foundedYear = _unset,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Publisher(
      id: id,
      name: name ?? this.name,
      city: city ?? this.city,
      foundedYear:
          foundedYear == _unset ? this.foundedYear : foundedYear as int?,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  static const _unset = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'foundedYear': foundedYear,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Publisher.fromJson(Map<String, dynamic> j) => Publisher(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        foundedYear: (j['foundedYear'] as num?)?.toInt(),
        deletedAt: j['deletedAt'] == null
            ? null
            : DateTime.tryParse(j['deletedAt'] as String),
      );
}
