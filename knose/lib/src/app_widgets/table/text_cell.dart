import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;

part 'text_cell.g.dart';

@reader_widget
Widget _stringField(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<Optional<model.PalValue>> string,
  bool enabled = true,
}) {
  return TableCellTextField(
    ctx: ctx,
    value: string,
    toText: (Optional<model.PalValue> value) => (value.unwrap?.value ?? '') as String,
    parse: (text) => Optional(model.PalValue(model.textType, text)),
    expands: true,
    enabled: enabled,
  );
}

@reader_widget
Widget _numField(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<Optional<model.PalValue>> number,
  bool enabled = true,
}) {
  return TableCellTextField(
    ctx: ctx,
    value: number,
    toText: (Optional<model.PalValue> value) => value.unwrap?.value.toString() ?? '',
    parse: (text) => Optional.fromNullable(num.tryParse(text)).map((n) => model.PalValue(model.numberType, n)),
    expands: false,
    enabled: enabled,
  );
}

@reader_widget
Widget _tableCellTextField<T>(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<Optional<T>> value,
  required String Function(Optional<T>) toText,
  required Optional<T> Function(String) parse,
  required bool expands,
  bool enabled = true,
}) {
  final isOpen = useCursor(false);
  final textStyle = Theme.of(context).textTheme.bodyText2;
  const padding = EdgeInsetsDirectional.only(top: 10, bottom: 5, start: 5, end: 0);
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
    offset: const Offset(-1, -1),
    childAnchor: Alignment.topLeft,
    dropdown: ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false),
      child: ModifiedIntrinsicWidth(
        modification: 2,
        child: Container(
          decoration: BoxDecoration(color: Theme.of(context).backgroundColor),
          alignment: AlignmentDirectional.topStart,
          child: TextFormField(
            initialValue: toText(value.read(Ctx.empty)),
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
                value.set(const Optional.none());
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
          toText(value.read(ctx)),
          style: textStyle,
          maxLines: expands ? 5 : 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}
