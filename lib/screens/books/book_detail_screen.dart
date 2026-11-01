import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../state/reference_data_notifier.dart';
import '../../state/book_list_notifier.dart';
import '../../widgets/app_scaffold.dart';

class BookDetailScreen extends StatelessWidget {
  final int id;
  const BookDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceDataNotifier>()..preload();
    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Книга')),
        body: FutureBuilder<Book?>(
          future: context.read<BookListNotifier>().findById(id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              // Сетевая ошибка не должна выглядеть как «запись не найдена»
              return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
            }
            final book = snapshot.data;
            if (book == null) {
              return const Center(child: Text('Книга не найдена'));
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(book.title,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    if (book.isDeleted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Удалена ${book.deletedAt}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            )),
                      ),
                    const SizedBox(height: 16),
                    _infoRow('ISBN', book.isbn, context),
                    _infoRow('Год издания', '${book.year}', context),
                    _infoRow('Страниц', '${book.pages}', context),
                    _infoRow('Издательство',
                        refs.publisherName(book.publisherId), context),
                    _infoRow(
                        'Авторы',
                        book.authorIds.isEmpty
                            ? '—'
                            : book.authorIds.map(refs.authorName).join(', '),
                        context),
                    _infoRow('Жанры',
                        book.genreIds.map(refs.genreName).join(', '), context),
                    _infoRow(
                        'Экземпляры',
                        '${book.copiesAvailable} из ${book.copiesTotal}',
                        context),
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
