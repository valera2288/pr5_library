import 'package:flutter/material.dart';

class Pagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  const Pagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Всего записей: $totalItems',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page),
              onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
              tooltip: 'Первая',
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed:
                  currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              tooltip: 'Предыдущая',
            ),
            Text('Стр. $currentPage из $totalPages'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: currentPage < totalPages
                  ? () => onPageChanged(currentPage + 1)
                  : null,
              tooltip: 'Следующая',
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              onPressed: currentPage < totalPages
                  ? () => onPageChanged(totalPages)
                  : null,
              tooltip: 'Последняя',
            ),
          ],
        ),
        DropdownButton<int>(
          value: pageSize,
          underline: const SizedBox.shrink(),
          items: const [10, 25, 50]
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('$s на стр.'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onPageSizeChanged(v);
          },
        ),
      ],
    );
  }
}
