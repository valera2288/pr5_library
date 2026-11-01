import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/permissions.dart';
import '../../models/reader.dart';
import '../../models/reader_query.dart';
import '../../state/reader_list_notifier.dart';
import '../../state/auth_notifier.dart';
import '../../state/load_status.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/entity_card_list.dart';
import '../../widgets/entity_table.dart';
import '../../widgets/pagination.dart';
import '../../widgets/search_field.dart';

class ReaderListScreen extends StatefulWidget {
  const ReaderListScreen({super.key});

  @override
  State<ReaderListScreen> createState() => _ReaderListScreenState();
}

class _ReaderListScreenState extends State<ReaderListScreen> {
  /// Права нужны только для того, чтобы не показывать лишние кнопки.
  /// Запрещает операцию сервер, ответом 403.
  bool _can(Permission p) => context.read<AuthNotifier>().can(p);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromUrl();
      if (context.read<ReaderListNotifier>().status == LoadStatus.idle) {
        context.read<ReaderListNotifier>().load();
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
    final queryFromUrl = ReaderQuery.fromUri(state.uri);
    final notifier = context.read<ReaderListNotifier>();
    if (notifier.query != queryFromUrl) {
      // didChangeDependencies вызывается во время сборки, а applyQuery сразу
      // уведомляет слушателей: откладываем до конца текущего кадра
      Future.microtask(() => notifier.applyQuery(queryFromUrl));
    }
  }

  void _applyQuery(ReaderQuery newQuery) {
    context.read<ReaderListNotifier>().applyQuery(newQuery);
    final uri =
        Uri(path: '/readers', queryParameters: newQuery.toQueryParameters());
    final qs = uri.query;
    context.go(qs.isEmpty ? '/readers' : '/readers?$qs');
  }

  void _confirmDeleteSelected() async {
    final notifier = context.read<ReaderListNotifier>();
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

  void _confirmSoftDelete(Reader r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить читателя?'),
        content: Text('${r.fullName} будет помечен как удалённый.'),
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
          context, () => context.read<ReaderListNotifier>().softDelete(r.id));
    }
  }

  void _confirmHardDelete(Reader r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить навсегда?'),
        content: Text('${r.fullName} будет стёрт полностью.'),
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
          context, () => context.read<ReaderListNotifier>().hardDelete(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ReaderListNotifier>();
    context.watch<AuthNotifier>(); // перерисовка при смене пользователя
    final screenSize = screenSizeOf(context);

    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Читатели'),
          actions: [
            if (_can(Permission.manageReaders))
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Новый читатель',
                onPressed: () => context.go('/readers/new'),
              ),
            if (notifier.hasSelection && _can(Permission.manageReaders)) ...[
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
                      hintText: 'ФИО, email или телефон...',
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

  Widget _buildBody(ReaderListNotifier notifier, ScreenSize screenSize) {
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

  Widget _buildList(ReaderListNotifier notifier, ScreenSize screenSize) {
    final columns = <TableColumnSpec<Reader>>[
      TableColumnSpec(
        label: 'ФИО',
        sortField: 'fullName',
        build: (r) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go('/readers/${r.id}'),
            child: Text(
              r.fullName,
              style: TextStyle(
                decoration: r.isDeleted ? TextDecoration.lineThrough : null,
                color: r.isDeleted ? Colors.grey : null,
              ),
            ),
          ),
        ),
      ),
      TableColumnSpec(
          label: 'Email', sortField: 'email', build: (r) => Text(r.email)),
      TableColumnSpec(label: 'Телефон', build: (r) => Text(r.phone)),
      TableColumnSpec(
          label: 'Билет',
          build: (r) => Text(r.card.number.isEmpty ? '—' : r.card.number)),
    ];

    List<Widget> buildActions(Reader r) {
      if (r.isDeleted) {
        return [
          if (_can(Permission.restore))
            IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'Восстановить',
                onPressed: () => runAction(context,
                    () => context.read<ReaderListNotifier>().restore(r.id))),
          if (_can(Permission.hardDelete))
            IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'Удалить навсегда',
                color: Theme.of(context).colorScheme.error,
                onPressed: () => _confirmHardDelete(r)),
        ];
      }
      return [
        if (_can(Permission.manageReaders))
          IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Редактировать',
              onPressed: () => context.go('/readers/${r.id}/edit')),
        if (_can(Permission.manageReaders))
          IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Удалить',
              onPressed: () => _confirmSoftDelete(r)),
      ];
    }

    return Column(
      children: [
        Expanded(
          child: screenSize == ScreenSize.compact
              ? ListView.builder(
                  itemCount: notifier.result.items.length,
                  itemBuilder: (c, i) {
                    final r = notifier.result.items[i];
                    return EntityCardItem<Reader>(
                      item: r,
                      id: r.id,
                      title: r.fullName,
                      subtitle: r.email,
                      selectable: _can(Permission.manageReaders),
                      selected: notifier.selected.contains(r.id),
                      onToggleSelect: () => notifier.toggleSelection(r.id),
                      onTap: () => context.go('/readers/${r.id}'),
                      fields: [
                        Text('Тел.: ${r.phone}'),
                        Text('Билет: ${r.card.number}'),
                      ],
                      actions: buildActions(r),
                    );
                  },
                )
              : EntityTable<Reader>(
                  columns: columns,
                  items: notifier.result.items,
                  idOf: (r) => r.id,
                  selected: notifier.selected,
                  onToggleSelect: _can(Permission.manageReaders)
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
