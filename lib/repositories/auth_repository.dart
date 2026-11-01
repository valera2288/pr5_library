import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';
import '../models/page_result.dart';

/// Ответ входа и обновления токена (контракт, раздел 2).
class AuthResult {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AppUser user;
  const AuthResult(
      this.accessToken, this.refreshToken, this.expiresIn, this.user);

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        j['accessToken'] as String,
        j['refreshToken'] as String,
        (j['expiresIn'] as num?)?.toInt() ?? 900,
        AppUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}

abstract interface class AuthRepository {
  Future<AuthResult> login(String username, String password);
  Future<AppUser> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  });
  Future<AppUser> me();
  Future<AuthResult> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
}

class ApiAuthRepository implements AuthRepository {
  final Dio _dio;
  ApiAuthRepository(this._dio);

  @override
  Future<AuthResult> login(String username, String password) => guard(() async {
        final r = await _dio.post<Map<String, dynamic>>('/auth/login',
            data: {'username': username, 'password': password});
        return AuthResult.fromJson(r.data!);
      });

  /// Пароль уходит как есть: хеширует его сервер. Хеш, посчитанный
  /// в браузере, просто стал бы новым паролем.
  @override
  Future<AppUser> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  }) =>
      guard(() async {
        final r =
            await _dio.post<Map<String, dynamic>>('/auth/register', data: {
          'username': username,
          'password': password,
          'email': email,
          'fullName': fullName,
        });
        return AppUser.fromJson(r.data!);
      });

  @override
  Future<AppUser> me() => guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/auth/me');
        return AppUser.fromJson(r.data!);
      });

  @override
  Future<AuthResult> refresh(String refreshToken) => guard(() async {
        final r = await _dio.post<Map<String, dynamic>>('/auth/refresh',
            data: {'refreshToken': refreshToken});
        return AuthResult.fromJson(r.data!);
      });

  @override
  Future<void> logout(String refreshToken) => guard(
      () => _dio.post('/auth/logout', data: {'refreshToken': refreshToken}));
}

/// Управление пользователями — только для администратора.
class UserRepository {
  final Dio _dio;
  UserRepository(this._dio);

  Future<PageResult<AppUser>> find({int page = 1, int size = 20}) =>
      guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/users',
            queryParameters: {'page': page, 'size': size, 'sort': 'id,asc'});
        final data = r.data!;
        return PageResult(
          items: ((data['items'] as List?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(AppUser.fromJson)
              .toList(),
          page: (data['page'] as num?)?.toInt() ?? page,
          size: (data['size'] as num?)?.toInt() ?? size,
          total: (data['total'] as num?)?.toInt() ?? 0,
        );
      });

  Future<AppUser> setRole(int id, Role role) => guard(() async {
        final r = await _dio.patch<Map<String, dynamic>>('/users/$id',
            data: {'role': role.name});
        return AppUser.fromJson(r.data!);
      });
}
