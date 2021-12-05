import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart' as model;
import 'package:flutter_hooks/flutter_hooks.dart';

part 'bool_cell.g.dart';

@reader_widget
Widget _boolCell(Cursor<model.PalValue> rowData, {required Ctx ctx, bool enabled = true}) {
  final boolCursor =
      rowData.value.cast<Optional<model.PalValue>>().orElse(falseValue).value.cast<bool>();

  return Checkbox(
    onChanged: !enabled ? null : (newValue) => boolCursor.set(newValue!),
    value: boolCursor.read(ctx),
  );
}

const falseValue = model.PalValue(model.booleanType, false);
