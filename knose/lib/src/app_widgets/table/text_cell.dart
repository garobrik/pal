import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';

part 'text_cell.g.dart';

@reader_widget
Widget _stringField(
  BuildContext context,
  Reader reader, {
  required Cursor<Optional<String>> string,
  bool enabled = true,
}) {
  return TableCellTextField(
    value: string,
    toText: (Optional<String> value) => value.orElse(''),
    parse: (text) => Optional(text),
    expands: true,
    enabled: enabled,
  );
}

@reader_widget
Widget _numField(
  BuildContext context,
  Reader reader, {
  required Cursor<Optional<num>> number,
  bool enabled = true,
}) {
  return TableCellTextField(
    value: number,
    toText: (Optional<num> value) => value.unwrap?.toString() ?? '',
    parse: (text) => Optional.fromNullable(num.tryParse(text)),
    expands: false,
    enabled: enabled,
  );
}

@reader_widget
Widget _tableCellTextField<T>(
  BuildContext context,
  Reader reader, {
  required Cursor<Optional<T>> value,
  required String Function(Optional<T>) toText,
  required Optional<T> Function(String) parse,
  required bool expands,
  bool enabled = true,
}) {
  final isOpen = useCursor(false);
  final textStyle = Theme.of(context).textTheme.bodyText2;
  final padding = EdgeInsetsDirectional.only(top: 10, bottom: 5, start: 5, end: 0);
  final padding2 = EdgeInsetsDirectional.only(
    top: padding.top - 5 + 1,
    bottom: padding.bottom + 1,
    start: padding.start + 1,
    end: 0,
  );
  final minWidth = useMemoized(() => expands ? 200.0 : 0.0, [expands]);
  final dropdownFocus = useFocusNode();

  return DeferredDropdown(
    modifyConstraints: (constraints) => BoxConstraints(
      minHeight: constraints.maxHeight + 2,
      maxHeight: constraints.maxHeight + 2,
      minWidth: constraints.maxWidth + 2,
      maxWidth: max(minWidth, constraints.maxWidth + 2),
    ),
    isOpen: isOpen,
    dropdownFocus: dropdownFocus,
    offset: Offset(-1, -1),
    childAnchor: Alignment.topLeft,
    dropdown: ScrollConfiguration(
      behavior: ScrollBehavior().copyWith(scrollbars: false),
      child: ModifiedIntrinsicWidth(
        modification: 2,
        child: Container(
          decoration: BoxDecoration(color: Theme.of(context).backgroundColor),
          alignment: AlignmentDirectional.topStart,
          child: TextFormField(
            initialValue: toText(value.read(null)),
            style: textStyle,
            focusNode: dropdownFocus,
            maxLines: expands ? null : 1,
            expands: expands,
            decoration: InputDecoration(
              focusedBorder: InputBorder.none,
              contentPadding: padding2,
            ),
            onChanged: (newText) {
              if (newText.isEmpty) {
                value.set(Optional.none());
              } else {
                parse(newText).ifPresent<T>((t) => value.set(Optional(t)));
              }
            },
          ),
        ),
      ),
    ),
    child: TextButton(
      style: ButtonStyle(
        padding: MaterialStateProperty.all(padding),
      ),
      onPressed: !enabled ? null : () => isOpen.set(true),
      child: Container(
        alignment: Alignment.topLeft,
        child: Text(
          toText(value.read(reader)),
          style: textStyle,
          maxLines: expands ? 5 : 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}
