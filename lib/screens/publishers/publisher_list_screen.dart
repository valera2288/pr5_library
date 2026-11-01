import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/permissions.dart';
import '../../models/publisher.dart';
import '../../models/publisher_query.dart';
import '../../state/publisher_list_notifier.dart';
import '../../state/auth_notifier.dart';
import '../../state/load_status.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/entity_card_list.dart';
import '../../widgets/entity_table.dart';
import '../../widgets/pagination.dart';
import '../../widgets/search_field.dart';

class PublisherListScreen extends StatefulWidget {
  const PublisherListScreen({super.key});

  @override
  State<PublisherListScreen> createState() => _PublisherListScreenState();
}

class _PublisherListScreenState extends State<PublisherListScreen> {
  /// Права нужны только для того, чтобы не показывать лишние кнопки.
  /// Запрещает операцию сервер, ответом 403.
  bool _can(Permission p) => context.read<AuthNotifier>().can(p);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromUrl();
      if (context.read<PublisherListNotifier>().status == LoadStatus.idle) {
        context.read<PublisherListNotifier>().load();
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
    final queryFromUrl = PublisherQuery.fromUri(state.uri);
    final notifier = context.read<PublisherListNotifier>();
    if (notifier.query != queryFromUrl) {
      // didChangeDependencies вызывается во время сборки, а applyQuery сразу
      // уведомляет слушателей: откладываем до конца текущего кадра
      Future.microtask(() => notifier.applyQuery(queryFromUrl));
    }
  }

  void _applyQuery(PublisherQuery newQuery) {
    context.read<PublisherListNotifier>().applyQuery(newQuery);
    final uri =
        Uri(path: '/publishers', queryParameters: newQuery.toQueryParameters());
    final qs = uri.query;
    context.go(qs.isEmpty ? '/publishers' : '/publishers?$qs');
  }

  void _confirmDeleteSelected() async {
    final notifier = context.read<PublisherListNotifier>();
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

  Future<void> _confirmSoftDelete(Publisher p) async {
    final notifier = context.read<PublisherListNotifier>();
    final count =
        await runAction(context, () => notifier.countBooksUsing(p.id));
    if (count == null) return;
    if (count > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Невозможно удалить: издательство используется в $count ${_pluralize(count, "книге", "книгах", "книгах")}'),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить издательство?'),
        content: Text('«${p.name}» будет помечено как удалённое.'),
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
      await runAction(context,
          () => context.read<PublisherListNotifier>().softDelete(p.id));
    }
  }

  void _confirmHardDelete(Publisher p) async {
    final notifier = context.read<PublisherListNotifier>();
    final count =
        await runAction(context, () => notifier.countBooksUsing(p.id));
    if (count == null) return;
    if (count > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Невозможно удалить: издательство используется в $count ${_pluralize(count, "книге", "книгах", "книгах")}'),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить навсегда?'),
        content: Text('«${p.name}» будет стёрто полностью.'),
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
      await runAction(context,
          () => context.read<PublisherListNotifier>().hardDelete(p.id));
    }
  }

  String _pluralize(int n, String one, String few, String many) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return few;
    return many;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<PublisherListNotifier>();
    context.watch<AuthNotifier>(); // перерисовка при смене пользователя
    final screenSize = screenSizeOf(context);

    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Издательства'),
          actions: [
            if (_can(Permission.manageCatalog))
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Новое издательство',
                onPressed: () => context.go('/publishers/new'),
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
                      hintText: 'Поиск издательства...',
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

  Widget _buildBody(PublisherListNotifier notifier, ScreenSize screenSize) {
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

  Widget _buildList(PublisherListNotifier notifier, ScreenSize screenSize) {
    final columns = <TableColumnSpec<Publisher>>[
      TableColumnSpec(
        label: 'Название',
        sortField: 'name',
        build: (p) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go('/publishers/${p.id}'),
            child: Text(
              p.name,
              style: TextStyle(
                decoration: p.isDeleted ? TextDecoration.lineThrough : null,
                color: p.isDeleted ? Colors.grey : null,
              ),
            ),
          ),
        ),
      ),
      TableColumnSpec(
        label: 'Город',
        sortField: 'city',
        build: (p) => Text(p.city.isEmpty ? '—' : p.city),
      ),
      TableColumnSpec(
        label: 'Основано',
        sortField: 'foundedYear',
        numeric: true,
        build: (p) => Text(p.foundedYear?.toString() ?? '—'),
      ),
    ];

    List<Widget> buildActions(Publisher p) {
      if (p.isDeleted) {
        return [
          if (_can(Permission.restore))
            IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'Восстановить',
                onPressed: () => runAction(context,
                    () => context.read<PublisherListNotifier>().restore(p.id))),
          if (_can(Permission.hardDelete))
            IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'Удалить навсегда',
                color: Theme.of(context).colorScheme.error,
                onPressed: () => _confirmHardDelete(p)),
        ];
      }
      return [
        if (_can(Permission.manageCatalog))
          IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Редактировать',
              onPressed: () => context.go('/publishers/${p.id}/edit')),
        if (_can(Permission.manageCatalog))
          IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Удалить',
              onPressed: () => _confirmSoftDelete(p)),
      ];
    }

    return Column(
      children: [
        Expanded(
          child: screenSize == ScreenSize.compact
              ? ListView.builder(
                  itemCount: notifier.result.items.length,
                  itemBuilder: (c, i) {
                    final p = notifier.result.items[i];
                    return EntityCardItem<Publisher>(
                      item: p,
                      id: p.id,
                      title: p.name,
                      subtitle: p.city.isEmpty ? null : p.city,
                      selectable: _can(Permission.manageCatalog),
                      selected: notifier.selected.contains(p.id),
                      onToggleSelect: () => notifier.toggleSelection(p.id),
                      onTap: () => context.go('/publishers/${p.id}'),
                      actions: buildActions(p),
                    );
                  },
                )
              : EntityTable<Publisher>(
                  columns: columns,
                  items: notifier.result.items,
                  idOf: (p) => p.id,
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
