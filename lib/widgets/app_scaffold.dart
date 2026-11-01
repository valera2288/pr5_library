import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../state/auth_notifier.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  /// Пункты меню и право, при котором пункт виден.
  static const _all = [
    (icon: Icons.home, label: 'Главная', path: '/', need: null),
    (
      icon: Icons.menu_book,
      label: 'Книги',
      path: '/books',
      need: Permission.viewCatalog
    ),
    (
      icon: Icons.person,
      label: 'Авторы',
      path: '/authors',
      need: Permission.viewCatalog
    ),
    (
      icon: Icons.bookmark,
      label: 'Мои выдачи',
      path: '/my-loans',
      need: Permission.viewOwnLoans
    ),
    (
      icon: Icons.category,
      label: 'Жанры',
      path: '/genres',
      need: Permission.manageCatalog
    ),
    (
      icon: Icons.business,
      label: 'Издательства',
      path: '/publishers',
      need: Permission.manageCatalog
    ),
    (
      icon: Icons.people,
      label: 'Читатели',
      path: '/readers',
      need: Permission.manageReaders
    ),
    (
      icon: Icons.swap_horiz,
      label: 'Выдачи',
      path: '/loans',
      need: Permission.manageLoans
    ),
    (
      icon: Icons.admin_panel_settings,
      label: 'Пользователи',
      path: '/admin/users',
      need: Permission.manageUsers
    ),
    (
      icon: Icons.bar_chart,
      label: 'Статистика',
      path: '/admin/stats',
      need: Permission.viewStats
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final destinations =
        _all.where((d) => d.need == null || auth.can(d.need!)).toList();
    final path = GoRouterState.of(context).uri.path;
    // Самый длинный совпавший префикс: «/» не должен перекрывать «/books»
    var selected = 0;
    for (var i = 0; i < destinations.length; i++) {
      final p = destinations[i].path;
      if (p != '/' && path.startsWith(p)) selected = i;
    }
    final size = screenSizeOf(context);
    final content = Column(
      children: [
        const _Header(),
        Expanded(child: child),
      ],
    );

    if (size == ScreenSize.compact) {
      // На узком экране в нижней панели помещается не больше пяти пунктов,
      // остальные остаются доступны с главного экрана
      final bottom = destinations.take(5).toList();
      return Scaffold(
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected < bottom.length ? selected : 0,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          onDestinationSelected: (i) => context.go(bottom[i].path),
          destinations: [
            for (final d in bottom)
              NavigationDestination(
                  icon: Icon(d.icon), label: d.label, tooltip: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(destinations[i].path),
            extended: size == ScreenSize.expanded,
            labelType: size == ScreenSize.expanded
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                    icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Шапка: название приложения, имя и роль пользователя, выход.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.local_library,
                size: 20, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Text('Библиотека', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (user != null) ...[
              Flexible(
                child: Text(
                  '${user.fullName} · ${user.role.title}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Выйти',
                icon: const Icon(Icons.logout, size: 20),
                onPressed: () => auth.logout(),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
