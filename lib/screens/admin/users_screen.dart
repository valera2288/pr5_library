import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/permissions.dart';
import '../../models/app_user.dart';
import '../../state/admin_notifiers.dart';
import '../../state/auth_notifier.dart';
import '../../state/load_status.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/app_scaffold.dart';

/// Учётные записи и роли — экран только для администратора.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<UsersNotifier>().load());
  }

  Future<void> _changeRole(AppUser user, Role role) async {
    final notifier = context.read<UsersNotifier>();
    final ok = await runAction(context, () async {
      await notifier.setRole(user, role);
      return true;
    });
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${user.username}: роль изменена на «${role.title}»')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<UsersNotifier>();
    final me = context.watch<AuthNotifier>().user;

    final Widget body = switch (notifier.status) {
      LoadStatus.idle ||
      LoadStatus.loading =>
        const Center(child: CircularProgressIndicator()),
      LoadStatus.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(notifier.error ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: notifier.load, child: const Text('Повторить')),
            ]),
          ),
        ),
      LoadStatus.success => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final u in notifier.users)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                      child: Text(u.username.isEmpty ? '?' : u.username[0])),
                  title: Text('${u.fullName} (${u.username})',
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(u.email.isEmpty ? '—' : u.email),
                  trailing: DropdownButton<Role>(
                    value: u.role,
                    // Снять роль с самого себя нельзя — это проверяет и сервер
                    onChanged: u.id == me?.id
                        ? null
                        : (r) {
                            if (r != null && r != u.role) _changeRole(u, r);
                          },
                    items: [
                      for (final r in Role.values)
                        DropdownMenuItem(value: r, child: Text(r.title)),
                    ],
                  ),
                ),
              ),
          ],
        ),
    };

    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Пользователи')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900), child: body),
        ),
      ),
    );
  }
}
