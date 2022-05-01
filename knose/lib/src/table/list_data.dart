import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide Column;
import 'package:flutter/material.dart' as flutter;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/table.dart' hide Column;
import 'package:knose/table.dart' as table;
import 'package:knose/pal.dart' as pal;

part 'list_data.g.dart';

final listTableData = pal.Value(
  listTableDataDef.asType(),
  listTableDataDef.instantiate({listTableDataElementID: textTableData}),
);

final listTableDataElementID = pal.MemberID();
final listTableDataDef = pal.DataDef.record(name: 'ListTableData', members: [
  pal.Member(id: listTableDataElementID, name: 'element', type: pal.Value),
]);

final listTableDataImpl = pal.Impl(
  implemented: tableDataDef.asType({tableDataImplementerID: listTableDataDef.asType()}),
  implementations: Dict({
    tableDataGetTypeID: pal.Literal(
      tableDataDef.memberType(tableDataGetTypeID),
      (Ctx ctx, Object arg) {
        final impl = arg as GetCursor<Object>;
        final elementDataImpl = impl.recordAccess(listTableDataElementID);
        final palImpl = pal.findImpl(
          ctx,
          tableDataDef.asType({tableDataImplementerID: elementDataImpl.palType().read(ctx)}),
        )!;
        return pal.List(
          palImpl.interfaceAccess(ctx, tableDataGetTypeID).callFn(ctx, elementDataImpl.palValue()),
        );
      },
    ),
    tableDataGetNameID: pal.Literal(
      tableDataDef.memberType(tableDataGetNameID),
      (Ctx _, Object __) => 'List',
    ),
    tableDataGetDefaultID: pal.Literal(
      tableDataDef.memberType(tableDataGetDefaultID),
      (Ctx _, Object __) => const Vec<Object>(),
    ),
    tableDataGetWidgetID: pal.Literal(
      tableDataDef.memberType(tableDataGetWidgetID),
      (Ctx ctx, Object args) {
        final impl = (args.mapAccess('impl').unwrap! as Cursor<Object>)
            .recordAccess(listTableDataElementID)
            .cast<pal.Value>();
        final list = (args.mapAccess('rowData').unwrap! as Cursor<Object>);

        return ListCell(
          ctx: ctx,
          list: list,
          dataImpl: impl,
        );
      },
    ),
    tableDataGetConfigID: pal.Literal(
      tableDataDef.memberType(tableDataGetConfigID),
      (Ctx ctx, Object args) {
        final column = args.mapAccess('column').unwrap! as Cursor<table.Column>;
        final dataImpl = args.mapAccess('impl').unwrap! as Cursor<Object>;
        return Optional(ListConfig(ctx: ctx, column: column, listImpl: dataImpl));
      },
    ),
  }),
);

@reader
Widget _listCell({
  required Cursor<Object> list,
  required Cursor<pal.Value> dataImpl,
  required Ctx ctx,
}) {
  final dropdownFocus = useFocusNode();
  final rawList = list.cast<Vec<Object>>();
  final palImpl = pal.findImpl(
    ctx,
    tableDataDef.asType({tableDataImplementerID: dataImpl.type.read(ctx)}),
  )!;
  final getWidget = palImpl.interfaceAccess(ctx, tableDataGetWidgetID);
  final getDefault = palImpl.interfaceAccess(ctx, tableDataGetDefaultID);

  return CellDropdown(
    constrainHeight: false,
    ctx: ctx,
    expands: true,
    dropdownFocus: dropdownFocus,
    dropdown: flutter.Column(
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
  required Cursor<table.Column> column,
  required Cursor<Object> listImpl,
  required Ctx ctx,
}) {
  final focusForImpl = useMemoized(() {
    final foci = <String, FocusNode>{};
    return (Cursor<pal.Value> impl, Ctx ctx) {
      return foci.putIfAbsent(tableDataGetName(ctx, impl), () => FocusNode());
    };
  });
  final elementImpl = listImpl.recordAccess(listTableDataElementID).cast<pal.Value>();

  final palImpl = pal.findImpl(
    ctx,
    tableDataDef.asType(
      {tableDataImplementerID: elementImpl.type.read(ctx)},
    ),
  )!;
  final getConfig = palImpl.interfaceAccess(ctx, tableDataGetConfigID);
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
    child: flutter.Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButtonDropdown(
          childAnchor: Alignment.topRight,
          dropdownAnchor: Alignment.topLeft,
          dropdownFocus: focusForImpl(elementImpl, ctx),
          dropdown: IntrinsicWidth(
            child: flutter.Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final type in columnTypes)
                  TextButton(
                    key: ValueKey(type),
                    focusNode: focusForImpl(Cursor(type), ctx),
                    onPressed: () {
                      if (type != elementImpl.read(ctx)) {
                        column.data.set(const Dict<RowID, Object>());
                        elementImpl.set(type);
                      }
                    },
                    child: Row(children: [
                      ReaderWidget(
                        ctx: ctx,
                        builder: (_, ctx) {
                          return Text(tableDataGetName(ctx, Cursor(type)));
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
