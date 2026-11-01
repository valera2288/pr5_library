import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/author.dart';
import '../../models/book.dart';
import '../../models/genre.dart';
import '../../models/publisher.dart';
import '../../repositories/book_repository.dart';
import '../../state/book_list_notifier.dart';
import '../../state/reference_data_notifier.dart';
import '../../widgets/entity_form.dart';
import '../../widgets/multi_select_field.dart';

class BookFormScreen extends StatefulWidget {
  final int? id;
  const BookFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _title = TextEditingController();
  final _isbn = TextEditingController();
  final _year = TextEditingController();
  final _pages = TextEditingController();
  final _copiesTotal = TextEditingController();
  final _copiesAvailable = TextEditingController();

  int? _publisherId;
  List<int> _authorIds = [];
  List<int> _genreIds = [];

  // Справочники загружаются один раз, а не при каждой перерисовке формы
  List<Author> _authors = [];
  List<Genre> _genres = [];
  List<Publisher> _publishers = [];

  /// Для каскада: какие авторы уже издавались в каком издательстве.
  Map<int, Set<int>> _authorsByPublisher = {};

  /// Каскад: после выбора издательства предлагаются только авторы,
  /// которые уже издавались в нём. Флажок позволяет снять ограничение,
  /// иначе нельзя было бы добавить книгу нового для издательства автора.
  bool _publisherAuthorsOnly = true;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Без обработки ошибка сети оставила бы форму с вечным индикатором
    _load().catchError((Object e) {
      if (mounted) setState(() => _error = 'Не удалось загрузить данные: $e');
    });
  }

  Future<void> _load() async {
    // Справочники берутся из кэша ReferenceDataNotifier: они запрашиваются
    // с сервера один раз, а не при каждом открытии формы
    final refs = context.read<ReferenceDataNotifier>();
    final booksFuture = context.read<BookRepository>().findAll();
    await refs.ensureLoaded();
    _authors = refs.authors;
    _genres = refs.genres;
    // Удалённые издательства оставляем: у книги может быть ссылка на такое,
    // и без него значение выпадающего списка не нашлось бы среди items
    _publishers = refs.allPublishers;
    _authorsByPublisher = {};
    for (final b in await booksFuture) {
      if (b.isDeleted || b.id == widget.id) continue;
      _authorsByPublisher
          .putIfAbsent(b.publisherId, () => {})
          .addAll(b.authorIds);
    }

    if (!mounted) return;
    if (widget.id == null) {
      setState(() => _loading = false);
      return;
    }
    final book = await context.read<BookRepository>().findById(widget.id!);
    if (!mounted) return;
    if (book == null) {
      setState(() => _error = 'Книга не найдена');
      return;
    }
    setState(() {
      _title.text = book.title;
      _isbn.text = book.isbn;
      _year.text = book.year.toString();
      _pages.text = book.pages.toString();
      _copiesTotal.text = book.copiesTotal.toString();
      _copiesAvailable.text = book.copiesAvailable.toString();
      _publisherId = book.publisherId;
      _authorIds = List.from(book.authorIds);
      _genreIds = List.from(book.genreIds);
      // При редактировании ограничение не включаем: у книги уже есть авторы
      _publisherAuthorsOnly = false;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _isbn.dispose();
    _year.dispose();
    _pages.dispose();
    _copiesTotal.dispose();
    _copiesAvailable.dispose();
    super.dispose();
  }

  /// Авторы, доступные для выбора с учётом выбранного издательства.
  /// Уже выбранные авторы остаются в списке, чтобы их можно было снять.
  List<Author> get _availableAuthors {
    final known = _authorsByPublisher[_publisherId];
    if (!_publisherAuthorsOnly || known == null || known.isEmpty) {
      return _authors;
    }
    return _authors
        .where((a) => known.contains(a.id) || _authorIds.contains(a.id))
        .toList();
  }

  Future<void> _submit() async {
    final repo = context.read<BookRepository>();
    final list = context.read<BookListNotifier>();
    final book = Book(
      id: widget.id ?? 0,
      title: _title.text.trim(),
      isbn: _isbn.text.trim(),
      year: int.parse(_year.text.trim()),
      pages: int.parse(_pages.text.trim()),
      publisherId: _publisherId!,
      authorIds: List.from(_authorIds),
      genreIds: List.from(_genreIds),
      copiesTotal: int.parse(_copiesTotal.text.trim()),
      copiesAvailable: int.parse(_copiesAvailable.text.trim()),
    );
    if (widget.isEditing) {
      await repo.update(book);
    } else {
      await repo.create(book);
    }
    // Список перечитывается, иначе новая запись не появится в нём
    // до смены фильтра: экран списка грузит данные только один раз
    await list.load();
  }

  @override
  Widget build(BuildContext context) {
    final bookRepo = context.read<BookRepository>();

    if (_loading || _error != null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.isEditing ? 'Редактирование книги' : 'Новая книга')),
        body: Center(
          child: _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Назад')),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final authors = _availableAuthors;
    String authorName(int id) =>
        _authors.where((a) => a.id == id).firstOrNull?.fullName ?? '#$id';

    return EntityForm(
      title: widget.isEditing ? 'Редактирование книги' : 'Новая книга',
      isEditing: widget.isEditing,
      onSubmit: _submit,
      fields: [
        EntityFormField(
          name: 'title',
          build: (_) => TextFormField(
            controller: _title,
            decoration: const InputDecoration(
                labelText: 'Название', border: OutlineInputBorder()),
            validator: V.combine([V.required(), V.length(min: 2, max: 300)]),
          ),
        ),
        EntityFormField(
          name: 'isbn',
          build: (_) => TextFormField(
            controller: _isbn,
            decoration: const InputDecoration(
                labelText: 'ISBN', border: OutlineInputBorder()),
            validator: V.combine([
              V.required(),
              V.isbn(),
              V.uniqueIsbn(bookRepo, exceptId: widget.id),
            ]),
          ),
        ),
        EntityFormField(
          name: 'year',
          build: (_) => TextFormField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Год издания', border: OutlineInputBorder()),
            validator: V.integer(min: 1450, max: 2100, label: 'Год'),
          ),
        ),
        EntityFormField(
          name: 'pages',
          build: (_) => TextFormField(
            controller: _pages,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Страниц', border: OutlineInputBorder()),
            validator: V.positive(label: 'Страниц'),
          ),
        ),
        EntityFormField(
          name: 'publisherId',
          build: (_) => DropdownButtonFormField<int>(
            initialValue: _publisherId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Издательство', border: OutlineInputBorder()),
            items: [
              for (final p in _publishers)
                if (!p.isDeleted || p.id == _publisherId)
                  DropdownMenuItem(
                    value: p.id,
                    child:
                        Text(p.city.isEmpty ? p.name : '${p.name} (${p.city})'),
                  ),
            ],
            onChanged: (v) => setState(() => _publisherId = v),
            validator: (v) => v == null ? 'Выберите издательство' : null,
          ),
        ),
        EntityFormField(
          name: 'publisherAuthorsOnly',
          build: (_) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _publisherAuthorsOnly,
            title: const Text('Предлагать только авторов этого издательства'),
            onChanged: (v) =>
                setState(() => _publisherAuthorsOnly = v ?? false),
          ),
        ),
        EntityFormField(
          name: 'authorIds',
          build: (_) => MultiSelectField<int>(
            // Ключ меняется вместе с набором вариантов, иначе поле
            // продолжит показывать старый список после смены издательства
            key: ValueKey('authors-$_publisherId-$_publisherAuthorsOnly'),
            initialValue: _authorIds,
            label: 'Авторы',
            options: authors.map((a) => a.id).toList(),
            labelOf: authorName,
            onChanged: (v) => _authorIds = v,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Выберите хотя бы одного автора'
                : null,
            chipBuilder: (id, selected, toggle) => FilterChip(
              label: Text(authorName(id)),
              selected: selected,
              onSelected: (_) => toggle(),
            ),
          ),
        ),
        EntityFormField(
          name: 'genreIds',
          build: (_) => MultiSelectField<int>(
            initialValue: _genreIds,
            label: 'Жанры',
            options: _genres.map((g) => g.id).toList(),
            labelOf: (id) => _genres.firstWhere((g) => g.id == id).name,
            onChanged: (v) => _genreIds = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Выберите хотя бы один жанр' : null,
            chipBuilder: (id, selected, toggle) => FilterChip(
              label: Text(_genres.firstWhere((g) => g.id == id).name),
              selected: selected,
              onSelected: (_) => toggle(),
            ),
          ),
        ),
        EntityFormField(
          name: 'copiesTotal',
          build: (_) => TextFormField(
            controller: _copiesTotal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Экземпляров всего', border: OutlineInputBorder()),
            validator: V.positive(label: 'Количество'),
          ),
        ),
        EntityFormField(
          name: 'copiesAvailable',
          build: (_) => TextFormField(
            controller: _copiesAvailable,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Экземпляров в наличии',
                border: OutlineInputBorder()),
            validator: (v) {
              final base = V.integer(min: 0, label: 'Количество')(v);
              if (base != null) return base;
              final total = int.tryParse(_copiesTotal.text.trim());
              if (total != null && int.parse(v!.trim()) > total) {
                return 'Не больше, чем экземпляров всего';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}
