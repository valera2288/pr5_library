import 'library_card.dart';

/// Читатель. Поля по контракту API:
/// `{ id, fullName, email, phone, card, deletedAt }`.
class Reader {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final LibraryCard card;
  final DateTime? deletedAt;

  const Reader({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.card,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  String get lastName => fullName.split(' ').first;

  Reader copyWith({
    String? fullName,
    String? email,
    String? phone,
    LibraryCard? card,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Reader(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      card: card ?? this.card,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'card': card.toJson(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Reader.fromJson(Map<String, dynamic> j) => Reader(
        id: (j['id'] as num?)?.toInt() ?? 0,
        fullName: _readFullName(j),
        email: (j['email'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        // Сервер может вернуть card: null, если билет не оформлен
        card: j['card'] is Map
            ? LibraryCard.fromJson(j['card'] as Map<String, dynamic>)
            : LibraryCard(number: '', issuedAt: DateTime.now()),
        deletedAt: j['deletedAt'] == null
            ? null
            : DateTime.tryParse(j['deletedAt'] as String),
      );

  /// Миграция со старого формата с полями firstName/lastName.
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
