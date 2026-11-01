import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book_query.dart';
import '../../state/reference_data_notifier.dart';
import '../../core/permissions.dart';
import '../../state/auth_notifier.dart';
import '../search_field.dart';

class BookFilters extends StatefulWidget {
  final BookQuery query;
  final ValueChanged<BookQuery> onQueryChanged;

  const BookFilters({
    super.key,
    required this.query,
    required this.onQueryChanged,
  });

  @override
  State<BookFilters> createState() => _BookFiltersState();
}

class _BookFiltersState extends State<BookFilters> {
  late final TextEditingController _yearFrom =
      TextEditingController(text: widget.query.yearFrom?.toString() ?? '');
  late final TextEditingController _yearTo =
      TextEditingController(text: widget.query.yearTo?.toString() ?? '');
  final FocusNode _yearFromFocus = FocusNode();
  final FocusNode _yearToFocus = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _yearFrom.dispose();
    _yearTo.dispose();
    _yearFromFocus.dispose();
    _yearToFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BookFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    final yf = widget.query.yearFrom?.toString() ?? '';
    final yt = widget.query.yearTo?.toString() ?? '';
    if (!_yearFromFocus.hasFocus && _yearFrom.text != yf) _yearFrom.text = yf;
    if (!_yearToFocus.hasFocus && _yearTo.text != yt) _yearTo.text = yt;
  }

  void _onYearsChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.onQueryChanged(widget.query.copyWith(
        yearFrom: int.tryParse(_yearFrom.text.trim()),
        yearTo: int.tryParse(_yearTo.text.trim()),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    final refs = context.watch<ReferenceDataNotifier>()..preload();
    final genres = refs.genres;
    final publishers = refs.publishers;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: SearchField(
            value: q.search,
            hintText: 'Название или ISBN...',
            onChanged: (v) => widget.onQueryChanged(q.copyWith(search: v)),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<int?>(
            key: ValueKey(q.genreId),
            initialValue: q.genreId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Жанр',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Любой')),
              for (final g in genres)
                DropdownMenuItem(
                  value: g.id,
                  child: Text(g.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => widget.onQueryChanged(
              v == null ? q.copyWith(genreId: null) : q.copyWith(genreId: v),
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<int?>(
            key: ValueKey(q.publisherId),
            initialValue: q.publisherId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Издательство',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Любое')),
              for (final p in publishers)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => widget.onQueryChanged(
              v == null
                  ? q.copyWith(publisherId: null)
                  : q.copyWith(publisherId: v),
            ),
          ),
        ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _yearFrom,
            focusNode: _yearFromFocus,
            decoration: const InputDecoration(
              labelText: 'Год с',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _onYearsChanged(),
          ),
        ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _yearTo,
            focusNode: _yearToFocus,
            decoration: const InputDecoration(
              labelText: 'Год по',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _onYearsChanged(),
          ),
        ),
        // Удалённые записи нужны только тому, кто может их восстановить
        if (context.watch<AuthNotifier>().can(Permission.restore))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Удалённые'),
              Switch(
                value: q.includeDeleted,
                onChanged: (v) =>
                    widget.onQueryChanged(q.copyWith(includeDeleted: v)),
              ),
            ],
          ),
      ],
    );
  }
}
