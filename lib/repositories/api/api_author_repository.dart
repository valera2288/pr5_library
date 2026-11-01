import 'package:dio/dio.dart';

import '../../models/author.dart';
import '../../models/author_query.dart';
import '../../models/page_result.dart';
import '../author_repository.dart';
import 'api_crud.dart';

class ApiAuthorRepository implements AuthorRepository {
  final ApiCrud<Author> _api;

  ApiAuthorRepository(Dio dio)
      : _api = ApiCrud(dio, '/authors', Author.fromJson);

  @override
  Future<PageResult<Author>> find(AuthorQuery q) async {
    final params = {
      if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      'sort': sortParam(q.sortField, q.sortAscending),
      if (q.includeDeleted) 'includeDeleted': true,
    };
    final hasLocalFilters =
        q.country != null || q.birthYearFrom != null || q.birthYearTo != null;
    if (!hasLocalFilters) {
      return _api.page({...params, 'page': q.page, 'size': q.size});
    }

    // Фильтров по стране и году рождения у /authors в контракте нет.
    // Авторов немного, поэтому в этом случае берём всех подходящих под поиск
    // и отбираем на клиенте; без этих фильтров работает серверная разбивка.
    final all = await _api.page({...params, 'page': 1, 'size': 100});
    final rows = all.items.where((a) {
      if (q.country != null && a.country != q.country) return false;
      final year = a.birthYear;
      if (q.birthYearFrom != null &&
          (year == null || year < q.birthYearFrom!)) {
        return false;
      }
      if (q.birthYearTo != null && (year == null || year > q.birthYearTo!)) {
        return false;
      }
      return true;
    }).toList();
    return pageLocally(rows, q.page, q.size);
  }

  @override
  Future<List<Author>> findAll() => _api.all(includeDeleted: true);

  @override
  Future<Author?> findById(int id) => _api.byId(id);

  @override
  Future<Author> create(Author a) => _api.create(_body(a));

  @override
  Future<Author> update(Author a) => _api.update(a.id, _body(a));

  Map<String, dynamic> _body(Author a) => {
        'fullName': a.fullName,
        'country': a.country,
        'birthYear': a.birthYear,
      };

  @override
  Future<void> softDelete(int id) => _api.softDelete(id);

  @override
  Future<void> hardDelete(int id) => _api.hardDelete(id);

  @override
  Future<void> restore(int id) => _api.restore(id);

  @override
  Future<int> deleteMany(List<int> ids) => _api.deleteMany(ids);
}
