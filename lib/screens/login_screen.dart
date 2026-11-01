import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/validators.dart';
import '../state/auth_notifier.dart';

class LoginScreen extends StatefulWidget {
  /// Куда вернуться после входа. Сам переход выполняет redirect маршрутизатора.
  final String? from;
  const LoginScreen({super.key, this.from});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    // Почему сессия завершилась: неактивность, срок сессии, истёкший токен
    _info = context.read<AuthNotifier>().takeEndReason();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await context
          .read<AuthNotifier>()
          .login(_username.text.trim(), _password.text);
    } on UnauthorizedException {
      if (mounted) setState(() => _error = 'Неверный логин или пароль');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(String username, String password) {
    _username.text = username;
    _password.text = password;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.local_library,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text('Библиотека',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 24),
                if (_info != null) ...[
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_info!)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _username,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Логин', border: OutlineInputBorder()),
                  validator: V.required('Введите логин'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Пароль', border: OutlineInputBorder()),
                  validator: V.required('Введите пароль'),
                  onFieldSubmitted: (_) => _submit(),
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
                      : const Text('Войти'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Нет учётной записи? Зарегистрироваться'),
                ),
                const SizedBox(height: 16),
                Text('Учётные записи учебного сервера:',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                        label: const Text('admin'),
                        onPressed: () => _fill('admin', 'admin123')),
                    ActionChip(
                        label: const Text('librarian'),
                        onPressed: () => _fill('librarian', 'librarian123')),
                    ActionChip(
                        label: const Text('reader'),
                        onPressed: () => _fill('reader', 'reader123')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
