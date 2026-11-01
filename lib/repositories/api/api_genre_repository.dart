import 'package:dio/dio.dart';

import '../../models/genre.dart';
import '../../models/genre_query.dart';
import '../../models/page_result.dart';
import '../genre_repository.dart';
import 'api_crud.dart';

class ApiGenreRepository implements GenreRepository {
  final ApiCrud<Genre> _api;

  ApiGenreRepository(Dio dio) : _api = ApiCrud(dio, '/genres', Genre.fromJson);

  @override
  Future<PageResult<Genre>> find(GenreQuery q) => _api.page({
        if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
        'sort': sortParam(q.sortField, q.sortAscending),
        'page': q.page,
        'size': q.size,
        if (q.includeDeleted) 'includeDeleted': true,
      });

  @override
  Future<List<Genre>> findAll() => _api.all(includeDeleted: true);

  @override
  Future<Genre?> findById(int id) => _api.byId(id);

  @override
  Future<Genre> create(Genre g) => _api.create(_body(g));

  @override
  Future<Genre> update(Genre g) => _api.update(g.id, _body(g));

  Map<String, dynamic> _body(Genre g) =>
      {'name': g.name, 'description': g.description};

  @override
  Future<void> softDelete(int id) => _api.softDelete(id);

  @override
  Future<void> hardDelete(int id) => _api.hardDelete(id);

  @override
  Future<void> restore(int id) => _api.restore(id);

  @override
  Future<int> deleteMany(List<int> ids) => _api.deleteMany(ids);
}
