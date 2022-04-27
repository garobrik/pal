import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide DataCell;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
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

@reader
Widget _listConfig({
  required Cursor<model.Column> column,
  required Cursor<Object> listImpl,
  required Ctx ctx,
}) {
  final focusForImpl = useMemoized(() {
    final foci = <String, FocusNode>{};
    return (Cursor<pal.Value> impl, Ctx ctx) {
      return foci.putIfAbsent(model.tableDataGetName(ctx, impl), () => FocusNode());
    };
  });
  final elementImpl = listImpl.recordAccess(model.listTableDataElementID).cast<pal.Value>();

  final palImpl = pal.findImpl(
    ctx,
    model.tableDataDef.asType(
      {model.tableDataImplementerID: elementImpl.type.read(ctx)},
    ),
  )!;
  final getConfig = palImpl.interfaceAccess(ctx, model.tableDataGetConfigID);
  final currentType = elementImpl.type.read(ctx);
  final specifiConfig = getConfig.callFn(
    ctx,
    Dict({
      'column': column,
      'impl': elementImpl
          .thenOpt<pal.Value>(OptLens(
            const [],
            (t) => t.type.assignableTo(ctx, currentType) ? Optional(t) : const Optional.none(),
            (t, f) => f(t),
          ))
          .value,
    }),
  ) as Optional<Widget>;

  return Container(
    padding: const EdgeInsetsDirectional.only(start: 10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButtonDropdown(
          childAnchor: Alignment.topRight,
          dropdownAnchor: Alignment.topLeft,
          dropdownFocus: focusForImpl(elementImpl, ctx),
          dropdown: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final type in columnTypes)
                  TextButton(
                    key: ValueKey(type),
                    focusNode: focusForImpl(Cursor(type), ctx),
                    onPressed: () {
                      if (type != elementImpl.read(ctx)) {
                        column.data.set(const Dict<model.RowID, Object>());
                        elementImpl.set(type);
                      }
                    },
                    child: Row(children: [
                      ReaderWidget(
                        ctx: ctx,
                        builder: (_, ctx) {
                          return Text(model.tableDataGetName(ctx, Cursor(type)));
                        },
                      )
                    ]),
                  ),
              ],
            ),
          ),
          child: Row(
            children: const [Icon(Icons.list), Text('Element type')],
          ),
        ),
        ...specifiConfig,
      ],
    ),
  );
}
