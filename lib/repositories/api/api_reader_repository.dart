import 'package:dio/dio.dart';

import '../../models/page_result.dart';
import '../../models/reader.dart';
import '../../models/reader_query.dart';
import '../reader_repository.dart';
import 'api_crud.dart';

class ApiReaderRepository implements ReaderRepository {
  final ApiCrud<Reader> _api;

  ApiReaderRepository(Dio dio)
      : _api = ApiCrud(dio, '/readers', Reader.fromJson);

  @override
  Future<PageResult<Reader>> find(ReaderQuery q) => _api.page({
        if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
        'sort': sortParam(q.sortField, q.sortAscending),
        'page': q.page,
        'size': q.size,
        if (q.includeDeleted) 'includeDeleted': true,
      });

  @override
  Future<List<Reader>> findAll() => _api.all();

  @override
  Future<Reader?> findById(int id) => _api.byId(id);

  /// Билет оформляет сервер, в теле передаются только поля читателя.
  @override
  Future<Reader> create(Reader r) => _api.create(_body(r));

  @override
  Future<Reader> update(Reader r) => _api.update(r.id, _body(r));

  Map<String, dynamic> _body(Reader r) =>
      {'fullName': r.fullName, 'email': r.email, 'phone': r.phone};

  @override
  Future<void> softDelete(int id) => _api.softDelete(id);

  @override
  Future<void> hardDelete(int id) => _api.hardDelete(id);

  @override
  Future<void> restore(int id) => _api.restore(id);

  @override
  Future<int> deleteMany(List<int> ids) => _api.deleteMany(ids);

  /// Уникальность почты проверяет сервер (422 с ошибкой в поле email).
  @override
  bool emailExists(String email, {int? exceptId}) => false;
}
