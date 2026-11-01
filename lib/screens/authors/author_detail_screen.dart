import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/author.dart';
import '../../state/author_list_notifier.dart';
import '../../widgets/app_scaffold.dart';

class AuthorDetailScreen extends StatelessWidget {
  final int id;
  const AuthorDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Автор')),
        body: FutureBuilder<Author?>(
          future: context.read<AuthorListNotifier>().findById(id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              // Сетевая ошибка не должна выглядеть как «запись не найдена»
              return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
            }
            final author = snapshot.data;
            if (author == null) {
              return const Center(child: Text('Автор не найден'));
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(author.fullName,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    if (author.isDeleted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Удалён ${author.deletedAt}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            )),
                      ),
                    const SizedBox(height: 16),
                    _infoRow('Страна',
                        author.country.isEmpty ? '—' : author.country, context),
                    _infoRow('Год рождения',
                        author.birthYear?.toString() ?? '—', context),
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
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
