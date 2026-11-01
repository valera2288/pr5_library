import 'package:dio/dio.dart';

import '../../models/page_result.dart';
import '../../models/publisher.dart';
import '../../models/publisher_query.dart';
import '../publisher_repository.dart';
import 'api_crud.dart';

class ApiPublisherRepository implements PublisherRepository {
  final ApiCrud<Publisher> _api;
  final ApiCrud<Object> _books;

  ApiPublisherRepository(Dio dio)
      : _api = ApiCrud(dio, '/publishers', Publisher.fromJson),
        _books = ApiCrud(dio, '/books', (j) => j);

  @override
  Future<PageResult<Publisher>> find(PublisherQuery q) async {
    final params = {
      if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      'sort': sortParam(q.sortField, q.sortAscending),
      if (q.includeDeleted) 'includeDeleted': true,
    };
    if (q.city == null) {
      return _api.page({...params, 'page': q.page, 'size': q.size});
    }
    // Фильтра по городу в контракте нет — отбираем на клиенте
    final all = await _api.page({...params, 'page': 1, 'size': 100});
    return pageLocally(
        all.items.where((p) => p.city == q.city).toList(), q.page, q.size);
  }

  @override
  Future<List<Publisher>> findAll() => _api.all(includeDeleted: true);

  @override
  Future<Publisher?> findById(int id) => _api.byId(id);

  @override
  Future<Publisher> create(Publisher p) => _api.create(_body(p));

  @override
  Future<Publisher> update(Publisher p) => _api.update(p.id, _body(p));

  Map<String, dynamic> _body(Publisher p) =>
      {'name': p.name, 'city': p.city, 'foundedYear': p.foundedYear};

  @override
  Future<void> softDelete(int id) => _api.softDelete(id);

  @override
  Future<void> hardDelete(int id) => _api.hardDelete(id);

  @override
  Future<void> restore(int id) => _api.restore(id);

  @override
  Future<int> deleteMany(List<int> ids) => _api.deleteMany(ids);

  /// Сервер не запрещает удалять издательство со связанными книгами,
  /// поэтому проверка остаётся на клиенте: число книг берём из total,
  /// не загружая сами книги.
  @override
  Future<int> countBooksUsing(int publisherId) =>
      _books.count({'publisherId': publisherId});
}
