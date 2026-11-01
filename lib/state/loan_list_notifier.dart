import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../models/loan.dart';
import '../models/reader.dart';
import '../models/page_result.dart';
import '../repositories/book_repository.dart';
import '../repositories/loan_repository.dart';
import '../repositories/reader_repository.dart';
import 'load_status.dart';

class LoanListNotifier extends ChangeNotifier {
  final LoanRepository _repository;
  final ReaderRepository _readers;
  final BookRepository _books;
  LoanListNotifier(this._repository, this._readers, this._books);

  /// Списки для диалога выдачи: все читатели и все книги.
  Future<(List<Reader>, List<Book>)> issueOptions() async {
    final readers = _readers.findAll();
    final books = _books.findAll();
    return (await readers, await books);
  }

  String? _status;
  int _page = 1;
  int _size = 10;
  PageResult<Loan> _result = PageResult.empty();
  LoadStatus _loadStatus = LoadStatus.idle;
  String? _error;
  int _loadSeq = 0;
  bool _disposed = false;

  String? get statusFilter => _status;
  int get size => _size;
  PageResult<Loan> get result => _result;
  LoadStatus get status => _loadStatus;
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final seq = ++_loadSeq;
    _loadStatus = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      final result =
          await _repository.find(status: _status, page: _page, size: _size);
      if (seq != _loadSeq) return;
      _result = result;
      _loadStatus = LoadStatus.success;
    } catch (e) {
      if (seq != _loadSeq) return;
      _error = 'Не удалось загрузить выдачи: $e';
      _loadStatus = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> setStatusFilter(String? value) {
    _status = value;
    _page = 1;
    return load();
  }

  Future<void> setPage(int page) {
    _page = page;
    return load();
  }

  Future<void> setSize(int size) {
    _size = size;
    _page = 1;
    return load();
  }

  /// Ошибки (409 — нет экземпляров, 401 — нужен вход) не глотаются:
  /// экран покажет их пользователю.
  Future<Loan> issue(
      {required int readerId, required int bookId, int days = 14}) async {
    final loan =
        await _repository.issue(readerId: readerId, bookId: bookId, days: days);
    await load();
    return loan;
  }

  Future<void> renew(int id) async {
    await _repository.renew(id);
    await load();
  }

  Future<void> returnLoan(int id) async {
    await _repository.returnLoan(id);
    await load();
  }
}
