import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Экран отказа: сюда ведёт redirect маршрута, если роли не хватает прав.
class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Доступ запрещён')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Недостаточно прав', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Этот раздел недоступен для вашей роли.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
