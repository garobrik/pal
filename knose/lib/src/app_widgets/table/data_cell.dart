import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/pal.dart' as pal;

part 'data_cell.g.dart';

@reader
Widget _dataCell(Cursor<Object> object, pal.Type type, {required Ctx ctx}) {
  if (type == pal.text) {
    return StringField(object, ctx: ctx);
  } else if (type == pal.number) {
    return NumField(object, ctx: ctx);
  } else if (type == pal.boolean) {
    return BoolCell(object, ctx: ctx);
  } else if (type is pal.List) {
    return const Text('List');
  } else if (type is pal.Map) {
    return const Text('Map');
  } else {
    return const Text('Unknown');
  }
}

@reader
Widget _typeSelector(Cursor<Object> type, {required Ctx ctx}) {
  return TextButtonDropdown(
    childAnchor: Alignment.topRight,
    dropdown: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final newType in [pal.text, pal.boolean, pal.number])
          TextButton(
            onPressed: () => type.set(newType),
            child: Text(newType.toString()),
          ),
      ],
    ),
    child: Row(children: [Text('Type: ${type.read(ctx).toString()}')]),
  );
}
