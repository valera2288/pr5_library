import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:library_app/core/api_client.dart';
import 'package:library_app/core/api_exceptions.dart';
import 'package:library_app/core/permissions.dart';
import 'package:library_app/models/book_query.dart';
import 'package:library_app/repositories/api/api_book_repository.dart';
import 'package:library_app/repositories/auth_repository.dart';
import 'package:library_app/state/auth_notifier.dart';

import 'fake_adapter.dart';

Map<String, dynamic> _session(String access, {String role = 'reader'}) => {
      'accessToken': access,
      'refreshToken': 'refresh-$access',
      'expiresIn': 60,
      'user': {
        'id': 3,
        'username': 'reader',
        'fullName': 'Смирнов П. А.',
        'role': role
      },
    };

/// Приложение в миниатюре: AuthNotifier, Dio с обновлением токена
/// и подменённый сервер, которым управляет [handler].
Future<(AuthNotifier, Dio, FakeAdapter)> _setup(FakeHandler handler) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = AuthNotifier(prefs);
  final dio = buildDio(
    baseUrl: 'http://test/api',
    tokenProvider: () => auth.accessToken,
    onUnauthorized: auth.refreshTokens,
  );
  final adapter = FakeAdapter(handler);
  dio.httpClientAdapter = adapter;
  auth.repository = ApiAuthRepository(dio);
  return (auth, dio, adapter);
}

void main() {
  test('вход сохраняет токены и пользователя', () async {
    final (auth, _, _) = await _setup((_) => (200, _session('A1')));
    await auth.login('reader', 'reader123');
    final prefs = await SharedPreferences.getInstance();

    expect(auth.isAuthenticated, isTrue);
    expect(auth.role, Role.reader);
    expect(prefs.getString('auth_access_token'), 'A1');
    expect(prefs.getString('auth_refresh_token'), 'refresh-A1');
  });

  test('неверный пароль не запускает обновление токена', () async {
    final (auth, _, adapter) =
        await _setup((_) => (401, {'message': 'Неверный логин или пароль'}));
    await expectLater(
        auth.login('reader', 'wrong'), throwsA(isA<UnauthorizedException>()));
    // Ровно один запрос: /auth/login. Обработчик 401 не трогает адреса /auth/
    expect(adapter.requests.map((r) => r.path), ['/auth/login']);
  });

  test('при 401 токен обновляется и запрос повторяется прозрачно', () async {
    final (auth, dio, adapter) = await _setup((o) {
      if (o.path == '/auth/login') return (200, _session('OLD'));
      if (o.path == '/auth/refresh') return (200, _session('NEW'));
      // Сервер принимает только новый токен
      final ok = o.headers['Authorization'] == 'Bearer NEW';
      return ok ? (200, pageOf([])) : (401, {'message': 'Токен истёк'});
    });
    await auth.login('reader', 'reader123');

    final page = await ApiBookRepository(dio).find(const BookQuery());

    expect(page.total, 0);
    expect(auth.accessToken, 'NEW');
    expect(adapter.requests.map((r) => r.path),
        ['/auth/login', '/books', '/auth/refresh', '/books']);
  });

  test('неудачное обновление завершает сессию без зацикливания', () async {
    final (auth, dio, adapter) = await _setup((o) {
      if (o.path == '/auth/login') return (200, _session('OLD'));
      return (401, {'message': 'Токен недействителен'});
    });
    await auth.login('reader', 'reader123');

    await expectLater(ApiBookRepository(dio).find(const BookQuery()),
        throwsA(isA<UnauthorizedException>()));

    expect(auth.isAuthenticated, isFalse);
    expect(auth.takeEndReason(), contains('Сессия истекла'));
    // login, books, refresh и всё: ни повторного обновления, ни цикла.
    // Выход отправляет logout с токеном обновления — он тоже учтён.
    final paths = adapter.requests.map((r) => r.path).toList();
    expect(paths.where((p) => p == '/auth/refresh'), hasLength(1));
    expect(paths.where((p) => p == '/books'), hasLength(1));
  });

  test('одновременные 401 ждут одно обновление', () async {
    final (auth, dio, adapter) = await _setup((o) async {
      if (o.path == '/auth/login') return (200, _session('OLD'));
      if (o.path == '/auth/refresh') {
        await Future.delayed(const Duration(milliseconds: 30));
        return (200, _session('NEW'));
      }
      final ok = o.headers['Authorization'] == 'Bearer NEW';
      return ok ? (200, pageOf([])) : (401, {'message': 'Токен истёк'});
    });
    await auth.login('reader', 'reader123');
    final repo = ApiBookRepository(dio);

    await Future.wait([
      dio.get('/genres'),
      dio.get('/authors'),
      repo.find(const BookQuery()),
    ]);

    expect(
        adapter.requests.where((r) => r.path == '/auth/refresh'), hasLength(1));
  });

  group('Восстановление сессии', () {
    Future<(AuthNotifier, SharedPreferences)> restoreWith(
        Map<String, String> extra) async {
      final (auth, _, _) = await _setup((_) => (200, _session('A1')));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_access_token', 'A1');
      await prefs.setString('auth_refresh_token', 'R1');
      await prefs.setString(
          'auth_user',
          jsonEncode({
            'id': 3,
            'username': 'reader',
            'fullName': 'Смирнов П. А.',
            'role': 'reader',
          }));
      await prefs.setString(
          'auth_last_activity', DateTime.now().toIso8601String());
      for (final e in extra.entries) {
        await prefs.setString(e.key, e.value);
      }
      await auth.restore();
      return (auth, prefs);
    }

    test('без времени входа отсчёт срока сессии начинается заново', () async {
      final (auth, prefs) = await restoreWith({});
      expect(auth.isAuthenticated, isTrue);
      expect(prefs.getString('auth_login_at'), isNotNull);
    });

    test('после предельного срока сессия завершается', () async {
      final old = DateTime.now().subtract(const Duration(days: 1));
      final (auth, prefs) =
          await restoreWith({'auth_login_at': old.toIso8601String()});
      expect(auth.isAuthenticated, isFalse);
      expect(auth.takeEndReason(), contains('максимальный срок'));
      expect(prefs.getString('auth_access_token'), isNull);
    });
  });

  test('выход удаляет токены', () async {
    final (auth, _, _) = await _setup(
        (o) => o.path == '/auth/login' ? (200, _session('A1')) : (204, null));
    await auth.login('reader', 'reader123');
    await auth.logout();
    final prefs = await SharedPreferences.getInstance();

    expect(auth.isAuthenticated, isFalse);
    expect(prefs.getString('auth_access_token'), isNull);
    expect(prefs.getString('auth_refresh_token'), isNull);
  });
}
