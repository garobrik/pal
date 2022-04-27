import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide DataCell;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/pal.dart' as pal;

part 'list_cell.g.dart';

@reader
Widget _listCell({
  required Cursor<Object> list,
  required Cursor<pal.Value> dataImpl,
  required bool enabled,
  required Ctx ctx,
}) {
  final dropdownFocus = useFocusNode();
  final rawList = list.cast<Vec<Object>>();
  final palImpl = pal.findImpl(
    ctx,
    model.tableDataDef.asType({model.tableDataImplementerID: dataImpl.type.read(ctx)}),
  )!;
  final getWidget = palImpl.interfaceAccess(ctx, model.tableDataGetWidgetID);
  final getDefault = palImpl.interfaceAccess(ctx, model.tableDataGetDefaultID);

  return CellDropdown(
    constrainHeight: false,
    enabled: enabled,
    ctx: ctx,
    expands: true,
    dropdownFocus: dropdownFocus,
    dropdown: Column(
      children: [
        for (final indexedValue in rawList.indexedValues(ctx))
          getWidget.callFn(
            ctx,
            Dict({
              'rowData': indexedValue.value,
              'impl': dataImpl.value,
            }),
          ) as Widget,
        TextButton(
          onPressed: () => rawList.add(getDefault.callFn(ctx, dataImpl.value)),
          child: const Text('Add new element'),
        ),
      ],
    ),
    child: Text('${rawList.length.read(ctx)} element list'),
  );
}
