import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:library_app/core/api_client.dart';
import 'package:library_app/core/api_exceptions.dart';
import 'package:library_app/models/book.dart';
import 'package:library_app/models/book_query.dart';
import 'package:library_app/repositories/api/api_book_repository.dart';
import 'package:library_app/repositories/loan_repository.dart';

import 'fake_adapter.dart';

const _bookJson = {
  'id': 1,
  'title': 'Война и мир',
  'isbn': '978-5-17-118366-4',
  'year': 1869,
  'pages': 1300,
  'publisher': {'id': 3, 'name': 'АСТ'},
  'authors': [
    {'id': 1, 'fullName': 'Толстой Л. Н.'}
  ],
  'genres': [
    {'id': 2, 'name': 'Роман'},
    {'id': 5, 'name': 'Классика'}
  ],
  'copiesTotal': 4,
  'copiesAvailable': 2,
  'deletedAt': null,
};

(Dio, FakeAdapter) _dio(FakeHandler handler) {
  final dio = buildDio(baseUrl: 'http://test/api');
  final adapter = FakeAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (dio, adapter);
}

Book _newBook() => const Book(
      id: 0,
      title: 'Тест',
      isbn: '978-5-17-118366-4',
      year: 2020,
      pages: 100,
      publisherId: 1,
      authorIds: [1],
      genreIds: [1],
      copiesTotal: 1,
      copiesAvailable: 1,
    );

void main() {
  test('find отправляет условия отбора серверу и разбирает страницу', () async {
    final (dio, adapter) = _dio((_) => (200, pageOf([_bookJson])));
    final page = await ApiBookRepository(dio).find(const BookQuery(
        search: 'война',
        genreId: 2,
        sortField: 'year',
        sortAscending: false,
        page: 2));

    final q = adapter.requests.single.queryParameters;
    expect(q['search'], 'война');
    expect(q['genreId'], 2);
    expect(q['sort'], 'year,desc');
    expect(q['page'], 2);
    expect(page.total, 1);
  });

  test('развёрнутые связи из ответа превращаются в идентификаторы', () async {
    final (dio, _) = _dio((_) => (200, _bookJson));
    final book = (await ApiBookRepository(dio).findById(1))!;
    expect(book.publisherId, 3);
    expect(book.authorIds, [1]);
    expect(book.genreIds, [2, 5]);
  });

  test('ответ 422 превращается в ValidationException с ошибками по полям',
      () async {
    final (dio, _) = _dio((_) => (
          422,
          {
            'message': 'Ошибка валидации',
            'errors': {'isbn': 'Книга с таким ISBN уже существует'},
          }
        ));
    expect(
      () => ApiBookRepository(dio).create(_newBook()),
      throwsA(isA<ValidationException>().having((e) => e.errors['isbn'], 'isbn',
          'Книга с таким ISBN уже существует')),
    );
  });

  test('ответ 409 при выдаче превращается в ConflictException', () async {
    final (dio, _) =
        _dio((_) => (409, {'message': 'Нет свободных экземпляров этой книги'}));
    expect(
      () => ApiLoanRepository(dio).issue(readerId: 1, bookId: 20),
      throwsA(isA<ConflictException>()
          .having((e) => e.message, 'message', contains('Нет свободных'))),
    );
  });

  test('ответ 404 на запрос записи даёт null, а не исключение', () async {
    final (dio, _) = _dio((_) => (404, {'message': 'Объект не найден'}));
    expect(await ApiBookRepository(dio).findById(999), isNull);
  });

  test('ответ 500 превращается в ServerException с текстом сервера', () async {
    final (dio, _) =
        _dio((_) => (500, {'message': 'Ошибка вызвана намеренно'}));
    expect(
      () => ApiBookRepository(dio).find(const BookQuery()),
      throwsA(isA<ServerException>()
          .having((e) => e.message, 'message', 'Ошибка вызвана намеренно')),
    );
  });

  test('недоступный сервер: чтение повторяется трижды, затем NetworkException',
      () async {
    final (dio, adapter) = _dio((o) => throw DioException.connectionError(
        requestOptions: o, reason: 'нет соединения'));
    await expectLater(
      ApiBookRepository(dio).find(const BookQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.requests, hasLength(4)); // первая попытка и три повтора
  });

  test('создание записи при сбое сети не повторяется', () async {
    final (dio, adapter) = _dio((o) => throw DioException.connectionError(
        requestOptions: o, reason: 'нет соединения'));
    await expectLater(
      ApiBookRepository(dio).create(_newBook()),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('новый запрос списка отменяет предыдущий', () async {
    final (dio, _) = _dio((_) async {
      await Future.delayed(const Duration(milliseconds: 50));
      return (200, pageOf([]));
    });
    final repo = ApiBookRepository(dio);
    final first = repo.find(const BookQuery(search: 'во'));
    final second = repo.find(const BookQuery(search: 'война'));
    await expectLater(first, throwsA(isA<CancelledException>()));
    expect((await second).items, isEmpty);
  });
}
