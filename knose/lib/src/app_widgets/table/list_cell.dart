import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide DataCell;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/pal.dart' as pal;

part 'list_cell.g.dart';

@reader
Widget _listCell({
  required Cursor<pal.Value> list,
  required bool enabled,
  required Ctx ctx,
}) {
  final dropdownFocus = useFocusNode();
  final rawList =
      list.palValue().cast<Optional<Object>>().optionalCast<Vec<Object>>().orElse(const Vec());
  final elementType =
      (list.palType().cast<pal.DataType>().read(ctx).assignments[pal.optionTypeID] as pal.List)
          .type;

  return CellDropdown(
    constrainHeight: false,
    enabled: enabled,
    ctx: ctx,
    expands: true,
    dropdownFocus: dropdownFocus,
    dropdown: Column(
      children: [
        for (final indexedValue in rawList.indexedValues(ctx))
          DataCell(
            value: indexedValue.value.wrap(pal.optionType(elementType)),
            ctx: ctx,
            enabled: enabled,
          ),
        TextButton(
          onPressed: () => rawList.add(const Optional<Object>.none()),
          child: const Text('Add new element'),
        ),
      ],
    ),
    child: Text('${rawList.length.read(ctx)} element list'),
  );
}
