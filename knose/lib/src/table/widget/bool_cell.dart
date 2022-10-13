import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'bool_cell.g.dart';

@reader
Widget _boolCell(Cursor<Object> rowData, {required Ctx ctx, bool enabled = true}) {
  final boolCursor = rowData.cast<bool>();

  return Checkbox(
    onChanged: !enabled ? null : (newValue) => boolCursor.set(newValue!),
    value: boolCursor.read(ctx),
  );
}
