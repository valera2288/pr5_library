import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/permissions.dart';
import '../../models/genre.dart';
import '../../models/genre_query.dart';
import '../../state/genre_list_notifier.dart';
import '../../state/auth_notifier.dart';
import '../../state/load_status.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/entity_card_list.dart';
import '../../widgets/entity_table.dart';
import '../../widgets/pagination.dart';
import '../../widgets/search_field.dart';

class GenreListScreen extends StatefulWidget {
  const GenreListScreen({super.key});

  @override
  State<GenreListScreen> createState() => _GenreListScreenState();
}

class _GenreListScreenState extends State<GenreListScreen> {
  /// Права нужны только для того, чтобы не показывать лишние кнопки.
  /// Запрещает операцию сервер, ответом 403.
  bool _can(Permission p) => context.read<AuthNotifier>().can(p);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromUrl();
      if (context.read<GenreListNotifier>().status == LoadStatus.idle) {
        context.read<GenreListNotifier>().load();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromUrl();
  }

  void _syncFromUrl() {
    final state = GoRouterState.of(context);
    final queryFromUrl = GenreQuery.fromUri(state.uri);
    final notifier = context.read<GenreListNotifier>();
    if (notifier.query != queryFromUrl) {
      // didChangeDependencies вызывается во время сборки, а applyQuery сразу
      // уведомляет слушателей: откладываем до конца текущего кадра
      Future.microtask(() => notifier.applyQuery(queryFromUrl));
    }
  }

  void _applyQuery(GenreQuery newQuery) {
    context.read<GenreListNotifier>().applyQuery(newQuery);
    final uri =
        Uri(path: '/genres', queryParameters: newQuery.toQueryParameters());
    final qs = uri.query;
    context.go(qs.isEmpty ? '/genres' : '/genres?$qs');
  }

  void _confirmDeleteSelected() async {
    final notifier = context.read<GenreListNotifier>();
    final count = notifier.selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить выбранные?'),
        content: Text('Будет удалено записей: $count. Продолжить?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final deleted = await runAction(context, notifier.softDeleteSelected);
      if (mounted && deleted != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Удалено: $deleted')));
      }
    }
  }

  void _confirmSoftDelete(Genre g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить жанр?'),
        content: Text('«${g.name}» будет помечен как удалённый.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await runAction(
          context, () => context.read<GenreListNotifier>().softDelete(g.id));
    }
  }

  void _confirmHardDelete(Genre g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить навсегда?'),
        content: Text('«${g.name}» будет стёрт полностью.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await runAction(
          context, () => context.read<GenreListNotifier>().hardDelete(g.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<GenreListNotifier>();
    context.watch<AuthNotifier>(); // перерисовка при смене пользователя
    final screenSize = screenSizeOf(context);

    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Жанры'),
          actions: [
            if (_can(Permission.manageCatalog))
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Новый жанр',
                onPressed: () => context.go('/genres/new'),
              ),
            if (notifier.hasSelection && _can(Permission.manageCatalog)) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Выбрано: ${notifier.selected.length}'),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.clear_all),
                  tooltip: 'Снять выделение',
                  onPressed: notifier.clearSelection),
              IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Удалить выбранные',
                  onPressed: _confirmDeleteSelected),
            ],
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: SearchField(
                      value: notifier.query.search,
                      hintText: 'Поиск жанра...',
                      onChanged: (v) =>
                          _applyQuery(notifier.query.copyWith(search: v)),
                    ),
                  ),
                  // Без показа удалённых их нельзя было бы восстановить
                  if (_can(Permission.restore))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Удалённые'),
                        Switch(
                          value: notifier.query.includeDeleted,
                          onChanged: (v) => _applyQuery(
                              notifier.query.copyWith(includeDeleted: v)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody(notifier, screenSize)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(GenreListNotifier notifier, ScreenSize screenSize) {
    switch (notifier.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadStatus.error:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(notifier.error ?? 'Ошибка',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: notifier.load, child: const Text('Повторить')),
          ]),
        );
      case LoadStatus.success:
        if (notifier.result.items.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.search_off, size: 64),
              SizedBox(height: 16),
              Text('Ничего не найдено'),
            ]),
          );
        }
        return _buildList(notifier, screenSize);
    }
  }

  Widget _buildList(GenreListNotifier notifier, ScreenSize screenSize) {
    final columns = <TableColumnSpec<Genre>>[
      TableColumnSpec(
        label: 'Название',
        sortField: 'name',
        build: (g) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go('/genres/${g.id}'),
            child: Text(
              g.name,
              style: TextStyle(
                decoration: g.isDeleted ? TextDecoration.lineThrough : null,
                color: g.isDeleted ? Colors.grey : null,
              ),
            ),
          ),
        ),
      ),
      TableColumnSpec(
        label: 'Описание',
        build: (g) => Text(
          g.description.isEmpty ? '—' : g.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];

    List<Widget> buildActions(Genre g) {
      if (g.isDeleted) {
        return [
          if (_can(Permission.restore))
            IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'Восстановить',
                onPressed: () => runAction(context,
                    () => context.read<GenreListNotifier>().restore(g.id))),
          if (_can(Permission.hardDelete))
            IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'Удалить навсегда',
                color: Theme.of(context).colorScheme.error,
                onPressed: () => _confirmHardDelete(g)),
        ];
      }
      return [
        if (_can(Permission.manageCatalog))
          IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Редактировать',
              onPressed: () => context.go('/genres/${g.id}/edit')),
        if (_can(Permission.manageCatalog))
          IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Удалить',
              onPressed: () => _confirmSoftDelete(g)),
      ];
    }

    return Column(
      children: [
        Expanded(
          child: screenSize == ScreenSize.compact
              ? ListView.builder(
                  itemCount: notifier.result.items.length,
                  itemBuilder: (c, i) {
                    final g = notifier.result.items[i];
                    return EntityCardItem<Genre>(
                      item: g,
                      id: g.id,
                      title: g.name,
                      subtitle: g.description.isEmpty ? null : g.description,
                      selectable: _can(Permission.manageCatalog),
                      selected: notifier.selected.contains(g.id),
                      onToggleSelect: () => notifier.toggleSelection(g.id),
                      onTap: () => context.go('/genres/${g.id}'),
                      actions: buildActions(g),
                    );
                  },
                )
              : EntityTable<Genre>(
                  columns: columns,
                  items: notifier.result.items,
                  idOf: (g) => g.id,
                  selected: notifier.selected,
                  onToggleSelect: _can(Permission.manageCatalog)
                      ? notifier.toggleSelection
                      : null,
                  sortField: notifier.query.sortField,
                  sortAscending: notifier.query.sortAscending,
                  onSort: (field) {
                    final q = notifier.query;
                    _applyQuery(q.copyWith(
                      sortField: field,
                      sortAscending:
                          field == q.sortField ? !q.sortAscending : true,
                    ));
                  },
                  actions: buildActions,
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Pagination(
            currentPage: notifier.result.page,
            totalPages: notifier.result.totalPages,
            totalItems: notifier.result.total,
            pageSize: notifier.query.size,
            onPageChanged: (p) => _applyQuery(notifier.query.withPage(p)),
            onPageSizeChanged: (s) =>
                _applyQuery(notifier.query.copyWith(size: s, page: 1)),
          ),
        ),
      ],
    );
  }
}
