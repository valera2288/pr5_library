import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/admin_notifiers.dart';
import '../../state/load_status.dart';
import '../../widgets/app_scaffold.dart';

/// Сводка по библиотеке — экран только для администратора.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<StatsNotifier>().load());
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<StatsNotifier>();
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
      LoadStatus.success => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final e in notifier.values.entries)
                  SizedBox(
                    width: 220,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${e.value}',
                                  style: theme.textTheme.displaySmall),
                              const SizedBox(height: 4),
                              Text(e.key),
                            ]),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
    };

    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Статистика'),
          actions: [
            IconButton(
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
                onPressed: notifier.load),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960), child: body),
        ),
      ),
    );
  }
}
