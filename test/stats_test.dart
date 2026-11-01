import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:library_app/repositories/api/api_author_repository.dart';
import 'package:library_app/repositories/api/api_book_repository.dart';
import 'package:library_app/repositories/api/api_reader_repository.dart';
import 'package:library_app/repositories/loan_repository.dart';
import 'package:library_app/state/admin_notifiers.dart';
import 'package:library_app/state/load_status.dart';

/// Адаптер, который отвечает с задержкой и, как настоящий, прерывается
/// отменой запроса. Обычная подмена отмену не воспроизводит.
class _SlowAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final cancelled = Completer<void>();
    cancelFuture?.then((_) => cancelled.complete());
    await Future.any([
      Future<void>.delayed(const Duration(milliseconds: 30)),
      cancelled.future,
    ]);
    if (cancelled.isCompleted) {
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'отменён',
      );
    }
    final deleted = options.queryParameters['includeDeleted'] == true;
    final total = deleted ? 5 : 4;
    final body = {
      'items': [
        for (var i = 1; i <= 1; i++) {'id': i},
      ],
      'page': 1,
      'size': 1,
      'total': total,
      'totalPages': total,
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('статистика не страдает от отмены запросов одного репозитория',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
      ..httpClientAdapter = _SlowAdapter();
    final stats = StatsNotifier(
      ApiBookRepository(dio),
      ApiAuthorRepository(dio),
      ApiReaderRepository(dio),
      ApiLoanRepository(dio),
    );

    await stats.load();

    // Раньше два параллельных запроса книг отменяли друг друга
    expect(stats.status, LoadStatus.success, reason: stats.error);
    expect(stats.values['Книг в каталоге'], 4);
    expect(stats.values['Книг удалено логически'], 1);
  });
}
