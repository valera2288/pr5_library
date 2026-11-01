import 'package:dio/dio.dart';

import '../../models/book.dart';
import '../../models/book_query.dart';
import '../../models/page_result.dart';
import '../book_repository.dart';
import 'api_crud.dart';

class ApiBookRepository implements BookRepository {
  final ApiCrud<Book> _api;

  ApiBookRepository(Dio dio) : _api = ApiCrud(dio, '/books', Book.fromJson);

  /// Поиск, фильтры, сортировка и разбивка на страницы выполняются сервером:
  /// клиент хранит только текущую страницу.
  @override
  Future<PageResult<Book>> find(BookQuery q) => _api.page({
        if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
        if (q.genreId != null) 'genreId': q.genreId,
        if (q.publisherId != null) 'publisherId': q.publisherId,
        if (q.yearFrom != null) 'yearFrom': q.yearFrom,
        if (q.yearTo != null) 'yearTo': q.yearTo,
        'sort': sortParam(q.sortField, q.sortAscending),
        'page': q.page,
        'size': q.size,
        if (q.includeDeleted) 'includeDeleted': true,
      });

  @override
  Future<List<Book>> findAll() => _api.all();

  @override
  Future<Book?> findById(int id) => _api.byId(id);

  @override
  Future<Book> create(Book book) => _api.create(book.toWriteJson());

  @override
  Future<Book> update(Book book) => _api.update(book.id, book.toWriteJson());

  @override
  Future<void> softDelete(int id) => _api.softDelete(id);

  @override
  Future<void> hardDelete(int id) => _api.hardDelete(id);

  @override
  Future<void> restore(int id) => _api.restore(id);

  @override
  Future<int> deleteMany(List<int> ids) => _api.deleteMany(ids);

  /// Уникальность ISBN проверяет сервер: при дубликате придёт 422
  /// с ошибкой в поле isbn, и форма покажет её под полем.
  @override
  bool isbnExists(String isbn, {int? exceptId}) => false;
}
