import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'bool_cell.g.dart';

@reader
Widget _boolCell(Cursor<Object> rowData, {required Ctx ctx, bool enabled = true}) {
  final boolCursor = rowData.cast<Optional<Object>>().optionalCast<bool>().orElse(false);

  return Checkbox(
    onChanged: !enabled ? null : (newValue) => boolCursor.set(newValue!),
    value: boolCursor.read(ctx),
  );
}
