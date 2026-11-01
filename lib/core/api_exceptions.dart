import 'package:dio/dio.dart';

/// Исключения предметной области. Виджеты и notifier'ы знают только о них,
/// про Dio и DioException им знать не нужно.
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Нет соединения, таймаут, сервер недоступен, заблокировано CORS
class NetworkException extends ApiException {
  const NetworkException(
      [super.message = 'Сервер недоступен. Проверьте соединение.']);
}

/// Запрос отменён, потому что пользователь уже отправил более новый
class CancelledException extends ApiException {
  const CancelledException([super.message = 'Запрос отменён.']);
}

/// 400 — сервер не смог разобрать запрос
class BadRequestException extends ApiException {
  const BadRequestException([super.message = 'Некорректный запрос.']);
}

/// 401 — не аутентифицирован либо срок действия токена истёк
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

/// 403 — роль не позволяет выполнить операцию
class ForbiddenException extends ApiException {
  const ForbiddenException(
      [super.message = 'Недостаточно прав для этого действия.']);
}

/// 404
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

/// 409 — нарушено ограничение целостности
class ConflictException extends ApiException {
  const ConflictException(super.message);
}

/// 422 — ошибки валидации по полям
class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(super.message, this.errors);
}

/// 5xx
class ServerException extends ApiException {
  const ServerException(
      [super.message = 'Ошибка на сервере. Попробуйте позже.']);
}

ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;
  return switch (status) {
    400 => BadRequestException(message ?? 'Некорректный запрос.'),
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 =>
      ForbiddenException(message ?? 'Недостаточно прав для этого действия.'),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
        message ?? 'Ошибка валидации',
        (body is Map && body['errors'] is Map)
            ? (body['errors'] as Map).map((k, v) => MapEntry('$k', '$v'))
            : const {},
      ),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

ApiException mapDioError(DioException e) {
  // Если исключение уже разобрал интерсептор, повторно его не разбираем.
  // Без этой проверки ошибка 422 придёт в приложение как ServerException.
  final existing = e.error;
  if (existing is ApiException) return existing;

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      const NetworkException('Сервер не ответил вовремя.'),
    DioExceptionType.connectionError => const NetworkException(
        'Не удалось соединиться с сервером. '
        'Если сервер запущен, откройте консоль браузера и проверьте наличие ошибки CORS.',
      ),
    DioExceptionType.cancel => const CancelledException(),
    // Коды 5xx: validateStatus их не пропускает, и dio бросает badResponse
    DioExceptionType.badResponse when e.response != null =>
      mapHttpError(e.response!.statusCode ?? 500, e.response!.data),
    // На web обрыв соединения и CORS иногда приходят как unknown
    DioExceptionType.unknown when e.response == null => const NetworkException(
        'Не удалось соединиться с сервером. '
        'Если сервер запущен, откройте консоль браузера и проверьте наличие ошибки CORS.',
      ),
    _ => const ServerException(),
  };
}

/// Обёртка для каждого сетевого вызова: наружу не выходит ни один DioException.
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
