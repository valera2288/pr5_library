import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../models/publisher.dart';
import '../models/page_result.dart';
import '../models/publisher_query.dart';
import '../repositories/publisher_repository.dart';
import 'load_status.dart';

class PublisherListNotifier extends ChangeNotifier {
  final PublisherRepository _repository;

  PublisherListNotifier(this._repository);

  PublisherQuery _query = const PublisherQuery();
  PageResult<Publisher> _result = PageResult<Publisher>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  bool _disposed = false;

  PublisherQuery get query => _query;
  PageResult<Publisher> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => UnmodifiableSetView(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// Номер последнего запроса. Если пользователь успел сменить условия,
  /// пока шла загрузка, ответ на устаревший запрос отбрасывается.
  int _loadSeq = 0;

  Future<void> load() async {
    final seq = ++_loadSeq;
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.find(_query);
      if (seq != _loadSeq) return;
      _result = result;
      _status = LoadStatus.success;
    } catch (e) {
      if (seq != _loadSeq) return;
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(PublisherQuery next) async {
    if (_query == next) return;
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(int id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _safeNotify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _safeNotify();
  }

  Future<int> softDeleteSelected() async {
    final count = await _repository.deleteMany(_selected.toList());
    _selected.clear();
    await load();
    return count;
  }

  Future<void> softDelete(int id) async {
    await _repository.softDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(int id) async {
    await _repository.hardDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(int id) async {
    await _repository.restore(id);
    await load();
  }

  /// Карточка записи: экраны получают данные через notifier,
  /// а не обращаются к репозиторию напрямую.
  Future<Publisher?> findById(int id) => _repository.findById(id);

  /// Сколько книг ссылается на издательство — перед удалением.
  Future<int> countBooksUsing(int publisherId) =>
      _repository.countBooksUsing(publisherId);
}
