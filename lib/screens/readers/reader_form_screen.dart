import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/reader.dart';
import '../../models/library_card.dart';
import '../../repositories/reader_repository.dart';
import '../../state/reader_list_notifier.dart';
import '../../widgets/entity_form.dart';

class ReaderFormScreen extends StatefulWidget {
  final int? id;
  const ReaderFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<ReaderFormScreen> createState() => _ReaderFormScreenState();
}

class _ReaderFormScreenState extends State<ReaderFormScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _cardNumber = TextEditingController();
  final _cardIssued = TextEditingController();
  final _cardValid = TextEditingController();

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
    final r = await context.read<ReaderRepository>().findById(widget.id!);
    if (!mounted) return;
    if (r == null) {
      setState(() => _error = 'Читатель не найден');
      return;
    }
    setState(() {
      _fullName.text = r.fullName;
      _email.text = r.email;
      _phone.text = r.phone;
      _cardNumber.text = r.card.number;
      _cardIssued.text = _dateToString(r.card.issuedAt);
      _cardValid.text =
          r.card.expiresAt == null ? '' : _dateToString(r.card.expiresAt!);
      _loading = false;
    });
  }

  String _dateToString(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(String s) {
    if (s.trim().isEmpty) return null;
    return DateTime.tryParse(s.trim());
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _cardNumber.dispose();
    _cardIssued.dispose();
    _cardValid.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = context.read<ReaderRepository>();
    final list = context.read<ReaderListNotifier>();
    final card = LibraryCard(
      number: _cardNumber.text.trim(),
      issuedAt: _parseDate(_cardIssued.text) ?? DateTime.now(),
      expiresAt: _parseDate(_cardValid.text),
    );
    final reader = Reader(
      id: widget.id ?? 0,
      fullName: _fullName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      card: card,
    );
    if (widget.isEditing) {
      await repo.update(reader);
    } else {
      await repo.create(reader);
    }
    // Список перечитывается, иначе новая запись не появится в нём
    // до смены фильтра: экран списка грузит данные только один раз
    await list.load();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ReaderRepository>();

    if (_loading || _error != null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(widget.isEditing
                ? 'Редактирование читателя'
                : 'Новый читатель')),
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
      title: widget.isEditing ? 'Редактирование читателя' : 'Новый читатель',
      isEditing: widget.isEditing,
      onSubmit: _submit,
      fields: [
        EntityFormField(
          name: 'fullName',
          build: (_) => TextFormField(
            controller: _fullName,
            decoration: const InputDecoration(
                labelText: 'ФИО',
                hintText: 'Иванов И. И.',
                border: OutlineInputBorder()),
            validator: V.combine([V.required(), V.length(min: 2, max: 150)]),
          ),
        ),
        EntityFormField(
          name: 'email',
          build: (_) => TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Email', border: OutlineInputBorder()),
            validator: V.combine([
              V.required(),
              V.email(),
              V.uniqueEmail(repo, exceptId: widget.id),
            ]),
          ),
        ),
        EntityFormField(
          name: 'phone',
          build: (_) => TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Телефон', border: OutlineInputBorder()),
            validator: V.combine([V.required(), V.phone()]),
          ),
        ),
        EntityFormField(
          name: 'card_header',
          // По контракту билет оформляет сервер: поля билета в запрос
          // не уходят, поэтому на форме они только для просмотра
          build: (_) => const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Читательский билет',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Оформляется сервером автоматически'),
              ],
            ),
          ),
        ),
        EntityFormField(
          name: 'cardNumber',
          build: (_) => TextFormField(
            controller: _cardNumber,
            enabled: false,
            decoration: const InputDecoration(
                labelText: 'Номер билета', border: OutlineInputBorder()),
          ),
        ),
        EntityFormField(
          name: 'cardIssued',
          build: (_) => TextFormField(
            controller: _cardIssued,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Дата выдачи',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
          ),
        ),
        EntityFormField(
          name: 'cardValid',
          build: (_) => TextFormField(
            controller: _cardValid,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Действителен до',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
          ),
        ),
      ],
    );
  }
}
