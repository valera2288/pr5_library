import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Экран для неизвестных адресов (errorBuilder у GoRouter).
class NotFoundScreen extends StatelessWidget {
  final String location;
  const NotFoundScreen({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Страница не найдена')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off,
                  size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text('404', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text('Адрес «$location» не существует',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/books'),
                icon: const Icon(Icons.menu_book),
                label: const Text('К каталогу книг'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
