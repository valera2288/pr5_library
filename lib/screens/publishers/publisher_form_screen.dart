import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/publisher.dart';
import '../../repositories/publisher_repository.dart';
import '../../state/reference_data_notifier.dart';
import '../../state/publisher_list_notifier.dart';
import '../../widgets/entity_form.dart';

class PublisherFormScreen extends StatefulWidget {
  final int? id;
  const PublisherFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<PublisherFormScreen> createState() => _PublisherFormScreenState();
}

class _PublisherFormScreenState extends State<PublisherFormScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _foundedYear = TextEditingController();

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
    final p = await context.read<PublisherRepository>().findById(widget.id!);
    if (!mounted) return;
    if (p == null) {
      setState(() => _error = 'Издательство не найдено');
      return;
    }
    setState(() {
      _name.text = p.name;
      _city.text = p.city;
      _foundedYear.text = p.foundedYear?.toString() ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _foundedYear.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = context.read<PublisherRepository>();
    final list = context.read<PublisherListNotifier>();
    final refs = context.read<ReferenceDataNotifier>();
    final year = _foundedYear.text.trim();
    final pub = Publisher(
      id: widget.id ?? 0,
      name: _name.text.trim(),
      city: _city.text.trim(),
      foundedYear: year.isEmpty ? null : int.parse(year),
    );
    if (widget.isEditing) {
      await repo.update(pub);
    } else {
      await repo.create(pub);
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
            title: Text(widget.isEditing
                ? 'Редактирование издательства'
                : 'Новое издательство')),
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
      title: widget.isEditing
          ? 'Редактирование издательства'
          : 'Новое издательство',
      isEditing: widget.isEditing,
      onSubmit: _submit,
      fields: [
        EntityFormField(
          name: 'name',
          build: (_) => TextFormField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Название', border: OutlineInputBorder()),
            validator: V.combine([V.required(), V.length(min: 2, max: 200)]),
          ),
        ),
        EntityFormField(
          name: 'city',
          build: (_) => TextFormField(
            controller: _city,
            decoration: const InputDecoration(
                labelText: 'Город', border: OutlineInputBorder()),
            validator: V.length(max: 100),
          ),
        ),
        EntityFormField(
          name: 'foundedYear',
          build: (_) => TextFormField(
            controller: _foundedYear,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Год основания (необязательно)',
                border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? null
                : V.integer(
                    min: 1400, max: DateTime.now().year, label: 'Год')(v),
          ),
        ),
      ],
    );
  }
}
