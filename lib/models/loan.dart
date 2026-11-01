/// Выдача книги читателю (контракт, раздел 4, Loan).
class Loan {
  final int id;
  final int readerId;
  final String readerName;
  final int bookId;
  final String bookTitle;
  final DateTime issuedAt;
  final DateTime dueAt;
  final DateTime? returnedAt;

  /// active, returned или overdue — статус вычисляет сервер.
  final String status;

  const Loan({
    required this.id,
    required this.readerId,
    required this.readerName,
    required this.bookId,
    required this.bookTitle,
    required this.issuedAt,
    required this.dueAt,
    this.returnedAt,
    this.status = 'active',
  });

  bool get isReturned => returnedAt != null;

  String get statusTitle => switch (status) {
        'returned' => 'Возвращена',
        'overdue' => 'Просрочена',
        _ => 'На руках',
      };

  factory Loan.fromJson(Map<String, dynamic> j) {
    final reader = j['reader'] is Map ? j['reader'] as Map : const {};
    final book = j['book'] is Map ? j['book'] as Map : const {};
    return Loan(
      id: (j['id'] as num?)?.toInt() ?? 0,
      readerId: (reader['id'] as num?)?.toInt() ?? 0,
      readerName: (reader['fullName'] as String?) ?? '—',
      bookId: (book['id'] as num?)?.toInt() ?? 0,
      bookTitle: (book['title'] as String?) ?? '—',
      issuedAt:
          DateTime.tryParse((j['issuedAt'] as String?) ?? '') ?? DateTime.now(),
      dueAt: DateTime.tryParse((j['dueAt'] as String?) ?? '') ?? DateTime.now(),
      returnedAt: DateTime.tryParse((j['returnedAt'] as String?) ?? ''),
      status: (j['status'] as String?) ?? 'active',
    );
  }
}
