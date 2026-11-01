import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exceptions.dart';

typedef FormFieldBuilder = Widget Function(BuildContext);

class EntityFormField {
  /// Имя поля. Совпадает с ключом в ошибках 422 от сервера (контракт,
  /// раздел 1.2), поэтому ошибка сервера показывается под нужным полем.
  final String name;
  final FormFieldBuilder build;
  const EntityFormField({required this.name, required this.build});
}

class EntityForm extends StatefulWidget {
  final String title;
  final List<EntityFormField> fields;
  final Future<void> Function() onSubmit;
  final bool isEditing;

  const EntityForm({
    super.key,
    required this.title,
    required this.fields,
    required this.onSubmit,
    this.isEditing = false,
  });

  @override
  State<EntityForm> createState() => EntityFormState();
}

class EntityFormState extends State<EntityForm> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  bool _dirty = false;

  /// Ошибки по полям из ответа 422.
  Map<String, String> _serverErrors = {};

  void markDirty() {
    setState(() {
      _dirty = true;
      // После правки ошибка сервера могла устареть: «ISBN занят» не должен
      // висеть после того, как пользователь ввёл другой ISBN
      _serverErrors = {};
    });
  }

  Future<void> _submit() async {
    // Повторное нажатие во время сохранения не создаёт вторую запись
    if (_submitting) return;
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit();
      if (!mounted) return;
      // Флаг сбрасывается через setState: PopScope читает canPop из последней
      // сборки, и без перестроения после сохранения снова спросил бы
      // «Несохранённые изменения». Уход — после кадра с новым canPop.
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.errors);
      // Ошибки по полям, которых нет на форме, показываем общим сообщением
      final names = widget.fields.map((f) => f.name).toSet();
      final rest = e.errors.entries.where((x) => !names.contains(x.key));
      _showMessage(rest.isEmpty
          ? 'Сервер отклонил данные — исправьте отмеченные поля'
          : rest.map((x) => x.value).join('\n'));
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, unauthorized: e is UnauthorizedException);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String text, {bool unauthorized = false}) {
    final router = GoRouter.of(context);
    final from = GoRouterState.of(context).uri.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        action: unauthorized
            ? SnackBarAction(
                label: 'Войти',
                onPressed: () => router.go(
                    Uri(path: '/login', queryParameters: {'from': from})
                        .toString()),
              )
            : null,
      ),
    );
  }

  Widget _withServerError(BuildContext context, EntityFormField f) {
    final error = _serverErrors[f.name];
    final field = f.build(context);
    if (error == null) return field;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 6),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 14, color: theme.colorScheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Несохранённые изменения'),
            content: const Text('Вы уверены, что хотите закрыть форму? '
                'Введённые данные будут потеряны.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Остаться'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: markDirty,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  for (final f in widget.fields) ...[
                    _withServerError(context, f),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.isEditing ? 'Сохранить' : 'Создать'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
