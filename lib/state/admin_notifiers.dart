import 'package:flutter/foundation.dart';

import '../core/permissions.dart';
import '../models/app_user.dart';
import '../models/author_query.dart';
import '../models/book_query.dart';
import '../models/page_result.dart';
import '../models/reader_query.dart';
import '../repositories/auth_repository.dart';
import '../repositories/author_repository.dart';
import '../repositories/book_repository.dart';
import '../repositories/loan_repository.dart';
import '../repositories/reader_repository.dart';
import 'load_status.dart';

/// Список пользователей и смена ролей — экран администратора.
class UsersNotifier extends ChangeNotifier {
  final UserRepository _repository;
  UsersNotifier(this._repository);

  List<AppUser> _users = [];
  LoadStatus _status = LoadStatus.idle;
  String? _error;

  List<AppUser> get users => _users;
  LoadStatus get status => _status;
  String? get error => _error;

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _users = (await _repository.find(size: 100)).items;
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить пользователей: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Ошибки (403, 409) не глотаются: экран покажет их сообщением.
  Future<void> setRole(AppUser user, Role role) async {
    final updated = await _repository.setRole(user.id, role);
    _users = [for (final u in _users) u.id == updated.id ? updated : u];
    notifyListeners();
  }
}

/// Сводные числа по библиотеке. Каждое число — общее количество записей
/// из ответа сервера (поле total), сами записи не загружаются.
class StatsNotifier extends ChangeNotifier {
  final BookRepository _books;
  final AuthorRepository _authors;
  final ReaderRepository _readers;
  final LoanRepository _loans;
  StatsNotifier(this._books, this._authors, this._readers, this._loans);

  Map<String, int> _values = {};
  LoadStatus _status = LoadStatus.idle;
  String? _error;

  Map<String, int> get values => _values;
  LoadStatus get status => _status;
  String? get error => _error;

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      // Репозиторий отменяет предыдущий запрос списка, когда начинается новый
      // (устаревший ответ не должен перезаписать свежий). Поэтому запросы
      // к одному репозиторию идут по очереди, а разные репозитории — параллельно.
      Future<List<PageResult<dynamic>>> books() async => [
            await _books.find(const BookQuery(size: 1)),
            await _books.find(const BookQuery(size: 1, includeDeleted: true)),
          ];
      Future<List<PageResult<dynamic>>> loans() async => [
            await _loans.find(status: 'active', size: 1),
            await _loans.find(status: 'overdue', size: 1),
            await _loans.find(status: 'returned', size: 1),
          ];
      final groups = await Future.wait([
        books(),
        _authors.find(const AuthorQuery(size: 1)).then((p) => [p]),
        _readers.find(const ReaderQuery(size: 1)).then((p) => [p]),
        loans(),
      ]);
      final r = [for (final g in groups) ...g];
      _values = {
        'Книг в каталоге': r[0].total,
        'Книг удалено логически': r[1].total - r[0].total,
        'Авторов': r[2].total,
        'Читателей': r[3].total,
        'Выдач на руках': r[4].total,
        'Просроченных выдач': r[5].total,
        'Возвращённых выдач': r[6].total,
      };
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить статистику: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }
}
