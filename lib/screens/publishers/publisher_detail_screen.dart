import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/permissions.dart';
import '../../models/publisher.dart';
import '../../state/publisher_list_notifier.dart';
import '../../state/auth_notifier.dart';
import '../../widgets/app_scaffold.dart';

class PublisherDetailScreen extends StatelessWidget {
  final int id;
  const PublisherDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Издательство')),
        body: FutureBuilder<Publisher?>(
          future: context.read<PublisherListNotifier>().findById(id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              // Сетевая ошибка не должна выглядеть как «запись не найдена»
              return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
            }
            final p = snapshot.data;
            if (p == null) {
              return const Center(child: Text('Издательство не найдено'));
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(p.name,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    if (p.isDeleted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Удалено ${p.deletedAt}',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer)),
                      ),
                    const SizedBox(height: 16),
                    _infoRow('Название', p.name, context),
                    _infoRow('Город', p.city.isEmpty ? '—' : p.city, context),
                    _infoRow('Год основания', p.foundedYear?.toString() ?? '—',
                        context),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (context
                            .watch<AuthNotifier>()
                            .can(Permission.manageCatalog)) ...[
                          FilledButton(
                            onPressed: () =>
                                context.go('/publishers/${p.id}/edit'),
                            child: const Text('Редактировать'),
                          ),
                          const SizedBox(width: 16),
                        ],
                        OutlinedButton(
                          onPressed: () => context.go('/publishers'),
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
