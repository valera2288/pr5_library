import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/permissions.dart';
import '../../models/reader.dart';
import '../../state/reader_list_notifier.dart';
import '../../state/auth_notifier.dart';
import '../../widgets/app_scaffold.dart';

class ReaderDetailScreen extends StatelessWidget {
  final int id;
  const ReaderDetailScreen({super.key, required this.id});

  String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Читатель')),
        body: FutureBuilder<Reader?>(
          future: context.read<ReaderListNotifier>().findById(id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              // Сетевая ошибка не должна выглядеть как «запись не найдена»
              return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
            }
            final r = snapshot.data;
            if (r == null) {
              return const Center(child: Text('Читатель не найден'));
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(r.fullName,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    if (r.isDeleted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Удалён ${r.deletedAt}',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer)),
                      ),
                    const SizedBox(height: 16),
                    _infoRow('Email', r.email, context),
                    _infoRow('Телефон', r.phone, context),
                    const Divider(height: 32),
                    Text('Читательский билет',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _infoRow('Номер', r.card.number, context),
                    _infoRow('Выдан', _fmt(r.card.issuedAt), context),
                    _infoRow(
                        'Действителен до',
                        r.card.expiresAt == null
                            ? '—'
                            : '${_fmt(r.card.expiresAt!)}${r.card.isExpired ? ' (истёк)' : ''}',
                        context),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (context
                            .watch<AuthNotifier>()
                            .can(Permission.manageReaders)) ...[
                          FilledButton(
                            onPressed: () =>
                                context.go('/readers/${r.id}/edit'),
                            child: const Text('Редактировать'),
                          ),
                          const SizedBox(width: 16),
                        ],
                        OutlinedButton(
                          onPressed: () => context.go('/readers'),
                          child: const Text('Назад к списку'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 160,
              child:
                  Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
