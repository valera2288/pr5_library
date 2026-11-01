import 'package:flutter/material.dart';

class MultiSelectField<T> extends FormField<List<T>> {
  MultiSelectField({
    super.key,
    required List<T> initialValue,
    required String label,
    required List<T> options,
    required String Function(T item) labelOf,
    required Widget Function(T item, bool selected, VoidCallback toggle)
        chipBuilder,
    ValueChanged<List<T>>? onChanged,
    super.validator,
  }) : super(
          initialValue: initialValue,
          builder: (field) {
            return InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                errorText: field.errorText,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((o) {
                  final selected = field.value?.contains(o) ?? false;
                  return chipBuilder(o, selected, () {
                    final next = List<T>.from(field.value ?? const []);
                    selected ? next.remove(o) : next.add(o);
                    field.didChange(next);
                    // без этого экран формы не узнает о выборе и сохранит пустой список
                    onChanged?.call(next);
                  });
                }).toList(),
              ),
            );
          },
        );
}
