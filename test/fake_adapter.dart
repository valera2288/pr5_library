import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = Object Function(RequestOptions options);

/// Подменяет сетевой слой Dio: вместо запроса к серверу вызывает [handler].
/// Обработчик возвращает (код, тело) либо бросает DioException.
class FakeAdapter implements HttpClientAdapter {
  final FakeHandler handler;
  final List<RequestOptions> requests = [];

  FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final result = handler(options);
    final value = result is Future ? await result : result;
    final (status, body) = value as (int, Object?);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> pageOf(List<Map<String, dynamic>> items,
        {int page = 1, int size = 10}) =>
    {
      'items': items,
      'page': page,
      'size': size,
      'total': items.length,
      'totalPages': 1,
    };
