import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/author.dart';
import '../../repositories/author_repository.dart';
import '../../state/reference_data_notifier.dart';
import '../../state/author_list_notifier.dart';
import '../../widgets/entity_form.dart';

class AuthorFormScreen extends StatefulWidget {
  final int? id;
  const AuthorFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<AuthorFormScreen> createState() => _AuthorFormScreenState();
}

class _AuthorFormScreenState extends State<AuthorFormScreen> {
  final _fullName = TextEditingController();
  final _country = TextEditingController();
  final _birthYear = TextEditingController();

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
    final a = await context.read<AuthorRepository>().findById(widget.id!);
    if (!mounted) return;
    if (a == null) {
      setState(() => _error = 'Автор не найден');
      return;
    }
    setState(() {
      _fullName.text = a.fullName;
      _country.text = a.country;
      _birthYear.text = a.birthYear?.toString() ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _fullName.dispose();
    _country.dispose();
    _birthYear.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = context.read<AuthorRepository>();
    final list = context.read<AuthorListNotifier>();
    final refs = context.read<ReferenceDataNotifier>();
    final birth = _birthYear.text.trim();
    final author = Author(
      id: widget.id ?? 0,
      fullName: _fullName.text.trim(),
      country: _country.text.trim(),
      birthYear: birth.isEmpty ? null : int.parse(birth),
    );
    if (widget.isEditing) {
      await repo.update(author);
    } else {
      await repo.create(author);
    }
    // Список перечитывается, иначе новая запись не появится в нём
    // до смены фильтра: экран списка грузит данные только один раз
    await list.load();
    // Новое имя должно сразу появиться в формах книг и подписях
    await refs.refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.isEditing ? 'Редактирование автора' : 'Новый автор')),
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
      title: widget.isEditing ? 'Редактирование автора' : 'Новый автор',
      isEditing: widget.isEditing,
      onSubmit: _submit,
      fields: [
        EntityFormField(
          name: 'fullName',
          build: (_) => TextFormField(
            controller: _fullName,
            decoration: const InputDecoration(
                labelText: 'ФИО',
                hintText: 'Толстой Л. Н.',
                border: OutlineInputBorder()),
            validator: V.combine([V.required(), V.length(min: 2, max: 150)]),
          ),
        ),
        EntityFormField(
          name: 'country',
          build: (_) => TextFormField(
            controller: _country,
            decoration: const InputDecoration(
                labelText: 'Страна', border: OutlineInputBorder()),
            validator: V.combine([V.required(), V.length(min: 2, max: 100)]),
          ),
        ),
        EntityFormField(
          name: 'birthYear',
          build: (_) => TextFormField(
            controller: _birthYear,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Год рождения (необязательно)',
                border: OutlineInputBorder()),
            // Год рождения по контракту необязателен
            validator: (v) => (v == null || v.trim().isEmpty)
                ? null
                : V.integer(
                    min: 1, max: DateTime.now().year, label: 'Год рождения')(v),
          ),
        ),
      ],
    );
  }
}
