import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_scaffold.dart';

/// Разделы главного экрана. Каждый виден только при нужном праве,
/// поэтому у читателя, библиотекаря и администратора разный набор плиток.
const _sections = [
  (
    Permission.viewCatalog,
    Icons.menu_book,
    'Каталог книг',
    'Поиск и просмотр книг',
    '/books'
  ),
  (
    Permission.viewCatalog,
    Icons.person,
    'Авторы',
    'Список авторов',
    '/authors'
  ),
  (
    Permission.viewOwnLoans,
    Icons.bookmark,
    'Мои выдачи',
    'Сроки возврата и продление',
    '/my-loans'
  ),
  (
    Permission.manageCatalog,
    Icons.category,
    'Жанры',
    'Справочник жанров',
    '/genres'
  ),
  (
    Permission.manageCatalog,
    Icons.business,
    'Издательства',
    'Справочник издательств',
    '/publishers'
  ),
  (
    Permission.manageReaders,
    Icons.people,
    'Читатели',
    'Читатели и билеты',
    '/readers'
  ),
  (
    Permission.manageLoans,
    Icons.swap_horiz,
    'Выдачи',
    'Оформление и возврат книг',
    '/loans'
  ),
  (
    Permission.manageUsers,
    Icons.admin_panel_settings,
    'Пользователи',
    'Учётные записи и роли',
    '/admin/users'
  ),
  (
    Permission.viewStats,
    Icons.bar_chart,
    'Статистика',
    'Сводка по библиотеке',
    '/admin/stats'
  ),
];

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final theme = Theme.of(context);
    final visible = _sections.where((s) => auth.can(s.$1)).toList();

    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Главная')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Здравствуйте, ${user?.fullName ?? ''}!',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('Роль: ${user?.role.title ?? '—'}',
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final (_, icon, title, subtitle, path) in visible)
                      SizedBox(
                        width: 280,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Icon(icon,
                                size: 32, color: theme.colorScheme.primary),
                            title: Text(title),
                            subtitle: Text(subtitle),
                            onTap: () => context.go(path),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
