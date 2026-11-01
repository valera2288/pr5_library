import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/validators.dart';
import '../state/auth_notifier.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  /// Ошибки по полям из ответа 422 (например, «Такой логин уже занят»).
  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    // Подсказки к паролю перерисовываются на каждый введённый символ
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_username, _fullName, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? Function(String?) _withServer(
          String field, String? Function(String?) local) =>
      (v) => local(v) ?? _serverErrors[field];

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // После успешной регистрации выполняется вход, и маршрутизатор
      // сам уводит с этого экрана на главную
      await context.read<AuthNotifier>().register(
            username: _username.text.trim(),
            password: _password.text,
            email: _email.text.trim(),
            fullName: _fullName.text.trim(),
          );
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.errors);
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = passwordRules(_password.text);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'К входу',
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            // Проверка по мере ввода, а не только по нажатию кнопки
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(
                      labelText: 'Логин', border: OutlineInputBorder()),
                  validator: _withServer(
                      'username',
                      V.combine([
                        V.required('Введите логин'),
                        V.length(min: 3, max: 30)
                      ])),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(
                      labelText: 'ФИО', border: OutlineInputBorder()),
                  validator: V.combine(
                      [V.required('Введите ФИО'), V.length(min: 2, max: 150)]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                  validator: _withServer('email',
                      V.combine([V.required('Введите почту'), V.email()])),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Пароль', border: OutlineInputBorder()),
                  validator: _withServer('password', V.strongPassword()),
                ),
                const SizedBox(height: 8),
                for (final (ok, text) in rules)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Row(children: [
                      Icon(
                          ok
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: ok ? Colors.green : theme.colorScheme.outline),
                      const SizedBox(width: 8),
                      Text(text, style: theme.textTheme.bodySmall),
                    ]),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Повтор пароля', border: OutlineInputBorder()),
                  validator: (v) =>
                      v != _password.text ? 'Пароли не совпадают' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Зарегистрироваться'),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Уже есть учётная запись? Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
