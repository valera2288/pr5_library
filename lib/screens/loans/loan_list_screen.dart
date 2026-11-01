import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../models/loan.dart';
import '../../models/reader.dart';
import '../../state/load_status.dart';
import '../../state/loan_list_notifier.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/entity_table.dart';
import '../../widgets/pagination.dart';

class LoanListScreen extends StatefulWidget {
  const LoanListScreen({super.key});

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> {
  static const _filters = <(String?, String)>[
    (null, 'Все'),
    ('active', 'На руках'),
    ('overdue', 'Просрочены'),
    ('returned', 'Возвращены'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoanListNotifier>().load();
    });
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _issue() async {
    final request = await showDialog<_IssueRequest>(
      context: context,
      builder: (_) => const _IssueDialog(),
    );
    if (request == null || !mounted) return;
    final loan = await runAction(
      context,
      () => context.read<LoanListNotifier>().issue(
          readerId: request.readerId,
          bookId: request.bookId,
          days: request.days),
    );
    if (loan != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Книга «${loan.bookTitle}» выдана до ${_date(loan.dueAt)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<LoanListNotifier>();
    final theme = Theme.of(context);

    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Выдачи'),
          actions: [
            TextButton.icon(
              onPressed: _issue,
              icon: const Icon(Icons.outbox),
              label: const Text('Выдать книгу'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in _filters)
                    ChoiceChip(
                      label: Text(label),
                      selected: notifier.statusFilter == value,
                      onSelected: (_) => notifier.setStatusFilter(value),
                    ),
                ],
              ),
            ),
            Expanded(
              child: switch (notifier.status) {
                LoadStatus.idle ||
                LoadStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                LoadStatus.error => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(notifier.error ?? '',
                              textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: notifier.load,
                            child: const Text('Повторить')),
                      ],
                    ),
                  ),
                LoadStatus.success when notifier.result.items.isEmpty =>
                  const Center(child: Text('Выдач нет')),
                LoadStatus.success => EntityTable<Loan>(
                    items: notifier.result.items,
                    idOf: (l) => l.id,
                    columns: [
                      TableColumnSpec(
                          label: 'Книга', build: (l) => Text(l.bookTitle)),
                      TableColumnSpec(
                          label: 'Читатель', build: (l) => Text(l.readerName)),
                      TableColumnSpec(
                          label: 'Выдана',
                          build: (l) => Text(_date(l.issuedAt))),
                      TableColumnSpec(
                          label: 'Вернуть до',
                          build: (l) => Text(_date(l.dueAt))),
                      TableColumnSpec(
                        label: 'Статус',
                        build: (l) => Text(
                          l.statusTitle,
                          style: TextStyle(
                            color: l.status == 'overdue'
                                ? theme.colorScheme.error
                                : null,
                          ),
                        ),
                      ),
                    ],
                    actions: (l) => [
                      if (!l.isReturned)
                        IconButton(
                          icon: const Icon(Icons.assignment_return),
                          tooltip: 'Принять книгу',
                          onPressed: () => runAction(
                              context, () => notifier.returnLoan(l.id)),
                        ),
                    ],
                  ),
              },
            ),
            if (notifier.status == LoadStatus.success &&
                notifier.result.total > 0)
              Pagination(
                currentPage: notifier.result.page,
                totalPages: notifier.result.totalPages,
                totalItems: notifier.result.total,
                pageSize: notifier.size,
                onPageChanged: notifier.setPage,
                onPageSizeChanged: notifier.setSize,
              ),
          ],
        ),
      ),
    );
  }
}

class _IssueRequest {
  final int readerId;
  final int bookId;
  final int days;
  const _IssueRequest(this.readerId, this.bookId, this.days);
}

/// Диалог оформления выдачи. Книги без свободных экземпляров в списке
/// оставлены намеренно: попытка их выдать показывает обработку ответа 409.
class _IssueDialog extends StatefulWidget {
  const _IssueDialog();

  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _days = TextEditingController(text: '14');
  late final Future<(List<Reader>, List<Book>)> _data = _loadData();
  int? _readerId;
  int? _bookId;

  Future<(List<Reader>, List<Book>)> _loadData() =>
      context.read<LoanListNotifier>().issueOptions();

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Выдать книгу'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Не удалось загрузить списки: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()));
            }
            final (readers, books) = snapshot.data!;
            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _readerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Читатель', border: OutlineInputBorder()),
                    items: [
                      for (final r in readers)
                        DropdownMenuItem(value: r.id, child: Text(r.fullName)),
                    ],
                    onChanged: (v) => _readerId = v,
                    validator: (v) => v == null ? 'Выберите читателя' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _bookId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Книга', border: OutlineInputBorder()),
                    items: [
                      for (final b in books)
                        DropdownMenuItem(
                          value: b.id,
                          child: Text(
                            '${b.title} — свободно ${b.copiesAvailable} из ${b.copiesTotal}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => _bookId = v,
                    validator: (v) => v == null ? 'Выберите книгу' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _days,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Срок, дней', border: OutlineInputBorder()),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      return (n == null || n < 1 || n > 90)
                          ? 'От 1 до 90 дней'
                          : null;
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(
                context,
                _IssueRequest(
                    _readerId!, _bookId!, int.parse(_days.text.trim())));
          },
          child: const Text('Выдать'),
        ),
      ],
    );
  }
}
