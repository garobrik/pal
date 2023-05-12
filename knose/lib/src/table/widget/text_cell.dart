import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/table.dart';

part 'text_cell.g.dart';

@reader
Widget _stringField(
  BuildContext context,
  Cursor<Object> string, {
  required Ctx ctx,
}) {
  return TableCellTextField(
    ctx: ctx,
    value: string,
    toText: (Object value) => value as String,
    parse: (text) => Optional(text),
    expands: true,
  );
}

@reader
Widget _numField(
  BuildContext context,
  Cursor<Object> number, {
  required Ctx ctx,
}) {
  return TableCellTextField(
    ctx: ctx,
    value: number,
    toText: (Object value) => (value as Optional<Object>).unwrap?.toString() ?? '',
    parse: (text) {
      if (text.isEmpty) return const Optional(Optional<Object>.none());
      return Optional.fromNullable(num.tryParse(text)).map(Optional.new);
    },
    expands: false,
  );
}

@reader
Widget _tableCellTextField<T>(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<T> value,
  required String Function(T) toText,
  required Optional<T> Function(String) parse,
  required bool expands,
}) {
  final textStyle = Theme.of(context).textTheme.bodyMedium;
  const padding = EdgeInsetsDirectional.only(top: 10, bottom: 5, start: 5, end: 0);
  final padding2 = EdgeInsetsDirectional.only(
    top: padding.top - 5 + 1,
    bottom: padding.bottom + 1,
    start: padding.start + 1,
    end: 0,
  );
  final dropdownFocus = useFocusNode();

  return CellDropdown(
    ctx: ctx,
    dropdownFocus: dropdownFocus,
    expands: expands,
    dropdown: ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false),
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.background),
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
            parse(newText).ifPresent((t) => value.set(t));
          },
        ),
      ),
    ),
    style: ButtonStyle(
      padding: MaterialStateProperty.all(padding),
    ),
    child: Container(
      alignment: Alignment.topLeft,
      child: Text(
        toText(value.read(ctx)),
        style: textStyle,
        maxLines: expands ? 5 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
