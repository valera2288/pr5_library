import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/genre.dart';
import '../../repositories/genre_repository.dart';
import '../../state/reference_data_notifier.dart';
import '../../state/genre_list_notifier.dart';
import '../../widgets/entity_form.dart';

class GenreFormScreen extends StatefulWidget {
  final int? id;
  const GenreFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<GenreFormScreen> createState() => _GenreFormScreenState();
}

class _GenreFormScreenState extends State<GenreFormScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();

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
    if (widget.id == null) {
      setState(() => _loading = false);
      return;
    }
    final g = await context.read<GenreRepository>().findById(widget.id!);
    if (!mounted) return;
    if (g == null) {
      setState(() => _error = 'Жанр не найден');
      return;
    }
    setState(() {
      _name.text = g.name;
      _description.text = g.description;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = context.read<GenreRepository>();
    final list = context.read<GenreListNotifier>();
    final refs = context.read<ReferenceDataNotifier>();
    final genre = Genre(
      id: widget.id ?? 0,
      name: _name.text.trim(),
      description: _description.text.trim(),
    );
    if (widget.isEditing) {
      await repo.update(genre);
    } else {
      await repo.create(genre);
    }
    // Список перечитывается, иначе новая запись не появится в нём
    // до смены фильтра: экран списка грузит данные только один раз
    await list.load();
    await refs.refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return Scaffold(
        appBar: AppBar(
            title:
                Text(widget.isEditing ? 'Редактирование жанра' : 'Новый жанр')),
        body: Center(
          child: _error != null
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Назад')),
                ])
              : const CircularProgressIndicator(),
        ),
      );
    }

    return EntityForm(
      title: widget.isEditing ? 'Редактирование жанра' : 'Новый жанр',
      isEditing: widget.isEditing,
      onSubmit: _submit,
      fields: [
        EntityFormField(
          name: 'name',
          build: (_) => TextFormField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Название', border: OutlineInputBorder()),
            validator: V.combine([V.required(), V.length(min: 2, max: 100)]),
          ),
        ),
        EntityFormField(
          name: 'description',
          build: (_) => TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Описание', border: OutlineInputBorder()),
            validator: V.length(max: 1000),
          ),
        ),
      ],
    );
  }
}
