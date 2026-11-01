import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/author_query.dart';
import '../../core/permissions.dart';
import '../../state/auth_notifier.dart';
import '../search_field.dart';

class AuthorFilters extends StatefulWidget {
  final AuthorQuery query;
  final ValueChanged<AuthorQuery> onQueryChanged;
  final List<String> countries;

  const AuthorFilters({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.countries,
  });

  @override
  State<AuthorFilters> createState() => _AuthorFiltersState();
}

class _AuthorFiltersState extends State<AuthorFilters> {
  late final TextEditingController _yearFrom =
      TextEditingController(text: widget.query.birthYearFrom?.toString() ?? '');
  late final TextEditingController _yearTo =
      TextEditingController(text: widget.query.birthYearTo?.toString() ?? '');
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
  void didUpdateWidget(AuthorFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    final yf = widget.query.birthYearFrom?.toString() ?? '';
    final yt = widget.query.birthYearTo?.toString() ?? '';
    if (!_yearFromFocus.hasFocus && _yearFrom.text != yf) _yearFrom.text = yf;
    if (!_yearToFocus.hasFocus && _yearTo.text != yt) _yearTo.text = yt;
  }

  void _onYearsChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.onQueryChanged(widget.query.copyWith(
        birthYearFrom: int.tryParse(_yearFrom.text.trim()),
        birthYearTo: int.tryParse(_yearTo.text.trim()),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: SearchField(
            value: q.search,
            hintText: 'ФИО или страна...',
            onChanged: (v) => widget.onQueryChanged(q.copyWith(search: v)),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String?>(
            key: ValueKey(q.country),
            initialValue: q.country,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Страна',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Любая')),
              for (final c in widget.countries)
                DropdownMenuItem(
                  value: c,
                  child: Text(c, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => widget.onQueryChanged(
              v == null ? q.copyWith(country: null) : q.copyWith(country: v),
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
