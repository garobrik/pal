import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/pal.dart' as pal;

part 'data_cell.g.dart';

@reader
Widget _dataCell({
  required Cursor<pal.Value> value,
  required Ctx ctx,
  required bool enabled,
  FocusNode? focusNode,
}) {
  final type = (value.palType().read(ctx) as pal.DataType).assignments[pal.optionTypeID]!;
  if (type == pal.text) {
    return StringField(value.palValue(), enabled: enabled, ctx: ctx);
  } else if (type == pal.number) {
    return NumField(value.palValue(), enabled: enabled, ctx: ctx);
  } else if (type == pal.boolean) {
    return BoolCell(value.palValue(), enabled: enabled, ctx: ctx);
  } else if (type is pal.List) {
    return ListCell(list: value, enabled: enabled, ctx: ctx);
  } else {
    return Text('$type');
  }
}

@reader
Widget _typeSelector(Cursor<Object> type, {required Ctx ctx, required bool topLevel}) {
  final focusForType = useMemoized(() {
    final foci = <Type, FocusNode>{};
    return (Type type) {
      return foci.putIfAbsent(type, () => FocusNode());
    };
  });

  late final Widget child;
  if (type.type(ctx) == pal.List) {
    child = Row(
      children: [
        if (topLevel) const Text('Type: '),
        const Text('List('),
        TypeSelector(
          type.cast<pal.List>().type,
          ctx: ctx,
          topLevel: false,
        ),
        const Text(')')
      ],
    );
  } else {
    child = Row(
      children: [
        if (topLevel) const Text('Type: '),
        Text(type.read(ctx).toString()),
      ],
    );
  }

  return TextButtonDropdown(
    style: ButtonStyle(
      padding: topLevel ? null : MaterialStateProperty.all(EdgeInsets.zero),
      minimumSize: topLevel ? null : MaterialStateProperty.all(Size.zero),
    ),
    dropdownFocus: focusForType(type.type(ctx)),
    childAnchor: Alignment.topRight,
    dropdown: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final newType in const [pal.text, pal.boolean, pal.number, pal.List(pal.text)])
          TextButton(
            focusNode: focusForType(newType.runtimeType),
            onPressed: () => type.set(newType),
            child: Text(newType.toString()),
          ),
      ],
    ),
    child: child,
  );
}
