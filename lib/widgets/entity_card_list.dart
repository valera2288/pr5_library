import 'package:flutter/material.dart';

class EntityCardItem<T> extends StatelessWidget {
  final T item;
  final int id;
  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final List<Widget> actions;
  final bool selected;
  final bool selectable;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onTap;

  const EntityCardItem({
    super.key,
    required this.item,
    required this.id,
    required this.title,
    this.subtitle,
    this.fields = const [],
    this.actions = const [],
    this.selected = false,
    this.selectable = false,
    this.onToggleSelect,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: selected ? cs.primaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectable) ...[
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onToggleSelect?.call(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (fields.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...fields,
              ],
              if (actions.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
