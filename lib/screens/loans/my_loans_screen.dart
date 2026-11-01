import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/loan.dart';
import '../../state/load_status.dart';
import '../../state/loan_list_notifier.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/app_scaffold.dart';

/// Выдачи текущего читателя. Сервер сам отдаёт читателю только его выдачи.
class MyLoansScreen extends StatefulWidget {
  const MyLoansScreen({super.key});

  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoanListNotifier>().setStatusFilter(null);
    });
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _renew(Loan loan) async {
    final notifier = context.read<LoanListNotifier>();
    final ok = await runAction(context, () async {
      await notifier.renew(loan.id);
      return true;
    });
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Срок по книге «${loan.bookTitle}» продлён на 7 дней')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<LoanListNotifier>();
    final theme = Theme.of(context);

    final Widget body = switch (notifier.status) {
      LoadStatus.idle ||
      LoadStatus.loading =>
        const Center(child: CircularProgressIndicator()),
      LoadStatus.error => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(notifier.error ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: notifier.load, child: const Text('Повторить')),
          ]),
        ),
      LoadStatus.success when notifier.result.items.isEmpty =>
        const Center(child: Text('У вас нет выдач')),
      LoadStatus.success => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final loan in notifier.result.items)
              Card(
                child: ListTile(
                  leading: Icon(
                    loan.isReturned
                        ? Icons.check_circle_outline
                        : Icons.menu_book,
                    color: loan.status == 'overdue'
                        ? theme.colorScheme.error
                        : null,
                  ),
                  title: Text(loan.bookTitle, overflow: TextOverflow.ellipsis),
                  subtitle: Text(loan.isReturned
                      ? 'Возвращена'
                      : '${loan.statusTitle}. Вернуть до ${_date(loan.dueAt)}'),
                  trailing: loan.isReturned
                      ? null
                      : OutlinedButton(
                          onPressed: () => _renew(loan),
                          child: const Text('Продлить'),
                        ),
                ),
              ),
          ],
        ),
    };

    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Мои выдачи')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800), child: body),
        ),
      ),
    );
  }
}
