import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exceptions.dart';

/// Выполняет действие, изменяющее данные (удаление, восстановление, выдача),
/// и показывает ошибку сервера понятным сообщением вместо необработанного
/// исключения. Возвращает null, если действие не удалось.
Future<T?> runAction<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final from = GoRouterState.of(context).uri.toString();
  final errorColor = Theme.of(context).colorScheme.error;
  try {
    return await action();
  } on ApiException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(e.message),
        backgroundColor: e is ConflictException ? errorColor : null,
        duration: const Duration(seconds: 5),
        action: e is UnauthorizedException
            ? SnackBarAction(
                label: 'Войти',
                onPressed: () => router.go(
                    Uri(path: '/login', queryParameters: {'from': from})
                        .toString()),
              )
            : null,
      ),
    );
    return null;
  }
}
