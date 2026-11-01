/// Читательский билет, связь с читателем один к одному.
/// Поля по контракту: `{ number, issuedAt, expiresAt }`.
class LibraryCard {
  final String number;
  final DateTime issuedAt;
  final DateTime? expiresAt;

  const LibraryCard({
    required this.number,
    required this.issuedAt,
    this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'number': number,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory LibraryCard.fromJson(Map<String, dynamic> j) => LibraryCard(
        number: (j['number'] as String?) ?? '',
        issuedAt: DateTime.tryParse((j['issuedAt'] as String?) ?? '') ??
            DateTime.now(),
        // validUntil — имя поля в старом формате хранилища
        expiresAt: DateTime.tryParse(
            (j['expiresAt'] ?? j['validUntil']) as String? ?? ''),
      );
}
