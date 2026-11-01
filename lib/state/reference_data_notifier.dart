import 'package:flutter/foundation.dart';

import '../models/author.dart';
import '../models/genre.dart';
import '../models/publisher.dart';
import '../repositories/author_repository.dart';
import '../repositories/genre_repository.dart';
import '../repositories/publisher_repository.dart';

/// Справочники для выпадающих списков и подписей: жанры, издательства, авторы.
///
/// Загружаются один раз и переиспользуются всеми экранами. После изменения
/// справочника форма вызывает [refresh], и подписи обновятся везде.
class ReferenceDataNotifier extends ChangeNotifier {
  final GenreRepository _genreRepository;
  final PublisherRepository _publisherRepository;
  final AuthorRepository _authorRepository;

  ReferenceDataNotifier(
    this._genreRepository,
    this._publisherRepository,
    this._authorRepository,
  );

  List<Genre> _genres = [];
  List<Publisher> _publishers = [];
  List<Author> _authors = [];
  Future<void>? _pending;
  bool _loaded = false;
  DateTime? _failedAt;

  /// Включая логически удалённые: у старой книги может остаться ссылка
  /// на удалённое издательство, и его название всё равно нужно показать.
  List<Genre> get allGenres => _genres;
  List<Publisher> get allPublishers => _publishers;
  List<Author> get allAuthors => _authors;

  /// Только действующие записи — для выбора в формах и фильтрах.
  List<Genre> get genres => _genres.where((g) => !g.isDeleted).toList();
  List<Publisher> get publishers =>
      _publishers.where((p) => !p.isDeleted).toList();
  List<Author> get authors => _authors.where((a) => !a.isDeleted).toList();

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() =>
      _loaded ? Future.value() : (_pending ??= refresh());

  /// Для вызова из build: не бросает исключение и после неудачи
  /// не повторяет загрузку чаще раза в 10 секунд, иначе при выключенном
  /// сервере каждая перерисовка отправляла бы новые запросы.
  void preload() {
    if (_loaded || _pending != null) return;
    final failed = _failedAt;
    if (failed != null &&
        DateTime.now().difference(failed) < const Duration(seconds: 10)) {
      return;
    }
    ensureLoaded().catchError((Object _) {});
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _genreRepository.findAll(),
        _publisherRepository.findAll(),
        _authorRepository.findAll(),
      ]);
      _genres = results[0] as List<Genre>;
      _publishers = results[1] as List<Publisher>;
      _authors = results[2] as List<Author>;
      _loaded = true;
      _failedAt = null;
      notifyListeners();
    } catch (_) {
      _failedAt = DateTime.now();
      rethrow;
    } finally {
      _pending = null;
    }
  }

  String genreName(int id) =>
      _genres.where((g) => g.id == id).firstOrNull?.name ?? '#$id';

  String publisherName(int id) =>
      _publishers.where((p) => p.id == id).firstOrNull?.name ?? '#$id';

  String authorName(int id) =>
      _authors.where((a) => a.id == id).firstOrNull?.fullName ?? '#$id';
}
