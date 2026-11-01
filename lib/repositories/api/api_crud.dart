import 'package:dio/dio.dart';

import '../../core/api_exceptions.dart';
import '../../models/page_result.dart';

/// Общие операции над ресурсом учебного API: `/books`, `/authors` и т. д.
///
/// Набор операций у всех ресурсов одинаковый (контракт, раздел 3),
/// поэтому пять репозиториев не повторяют один и тот же код, а делегируют
/// его этому классу.
class ApiCrud<T> {
  final Dio _dio;
  final String _path;
  final T Function(Map<String, dynamic>) _fromJson;

  ApiCrud(this._dio, this._path, this._fromJson);

  /// Токен последнего запроса списка. Новый запрос отменяет предыдущий:
  /// иначе ответ на «во» может прийти после ответа на «война» и затереть его.
  CancelToken? _pageToken;

  Future<PageResult<T>> page(Map<String, dynamic> params) {
    _pageToken?.cancel('Запрос устарел');
    final token = _pageToken = CancelToken();
    return guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: params,
        cancelToken: token,
      );
      return _parsePage(response.data, params);
    });
  }

  /// Все записи без постраничной разбивки — для справочников и выпадающих
  /// списков. Сервер отдаёт не больше 100 за раз, поэтому идём по страницам.
  Future<List<T>> all({bool includeDeleted = false}) => guard(() async {
        final items = <T>[];
        var page = 1;
        while (true) {
          final response =
              await _dio.get<Map<String, dynamic>>(_path, queryParameters: {
            'page': page,
            'size': 100,
            if (includeDeleted) 'includeDeleted': true,
          });
          final result = _parsePage(response.data, const {});
          items.addAll(result.items);
          if (!result.hasNext) return items;
          page++;
        }
      });

  Future<T?> byId(int id) async {
    try {
      return await guard(() async {
        // includeDeleted: карточку удалённой записи тоже нужно открыть,
        // чтобы её можно было восстановить
        final response = await _dio.get<Map<String, dynamic>>('$_path/$id',
            queryParameters: {'includeDeleted': true});
        return _fromJson(response.data!);
      });
    } on NotFoundException {
      return null;
    }
  }

  Future<T> create(Map<String, dynamic> body) => guard(() async {
        final response =
            await _dio.post<Map<String, dynamic>>(_path, data: body);
        return _fromJson(response.data!);
      });

  Future<T> update(int id, Map<String, dynamic> body) => guard(() async {
        final response =
            await _dio.put<Map<String, dynamic>>('$_path/$id', data: body);
        return _fromJson(response.data!);
      });

  Future<void> softDelete(int id) => guard(() => _dio.delete('$_path/$id'));

  Future<void> hardDelete(int id) =>
      guard(() => _dio.delete('$_path/$id', queryParameters: {'hard': true}));

  Future<void> restore(int id) => guard(() => _dio.post('$_path/$id/restore'));

  Future<int> deleteMany(List<int> ids) => guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
            '$_path/bulk-delete',
            data: {'ids': ids});
        return (response.data?['deleted'] as num?)?.toInt() ?? 0;
      });

  /// Число записей, подходящих под условия, без загрузки самих записей.
  Future<int> count(Map<String, dynamic> params) => guard(() async {
        final response = await _dio.get<Map<String, dynamic>>(_path,
            queryParameters: {...params, 'page': 1, 'size': 1});
        return (response.data?['total'] as num?)?.toInt() ?? 0;
      });

  PageResult<T> _parsePage(
      Map<String, dynamic>? data, Map<String, dynamic> params) {
    if (data == null) {
      throw const ServerException('Сервер вернул пустой ответ.');
    }
    return PageResult(
      items: ((data['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .toList(),
      page: (data['page'] as num?)?.toInt() ?? 1,
      size: (data['size'] as num?)?.toInt() ?? (params['size'] as int? ?? 10),
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Параметры сортировки в формате контракта: `title,asc`.
String sortParam(String field, bool ascending) =>
    '$field,${ascending ? 'asc' : 'desc'}';

/// Отбор, который сервер не поддерживает (например, авторы по стране),
/// выполняется на клиенте по полному списку и нарезается на страницы здесь.
PageResult<T> pageLocally<T>(List<T> rows, int page, int size) {
  final total = rows.length;
  final from = (page - 1) * size;
  final to = (from + size) > total ? total : (from + size);
  return PageResult(
    items: from >= total ? <T>[] : rows.sublist(from, to),
    page: page,
    size: size,
    total: total,
  );
}
