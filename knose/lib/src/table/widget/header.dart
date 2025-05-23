import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/widget.dart' as widget;
import 'package:knose/table.dart' hide Column;
import 'package:knose/table.dart' as pal_table;
import 'package:knose/pal.dart' as pal;

part 'header.g.dart';

final columnTypes = [
  textTableData,
  booleanTableData,
  numberTableData,
  listTableData,
  linkTableData,
];

@reader
Widget _tableHeader(
  BuildContext context,
  Cursor<Table> table, {
  required Ctx ctx,
}) {
  final openColumns = useCursor(const Dict<ColumnID, bool>());

  return Row(
    children: [
      ReorderResizeable(
        ctx: ctx,
        direction: Axis.horizontal,
        onReorder: (old, nu) {
          table.columnIDs.atomically((columnIDs) {
            columnIDs.insert(nu < old ? nu : nu + 1, columnIDs[old].read(Ctx.empty));
            columnIDs.remove(nu < old ? old + 1 : old);
          });
        },
        mainAxisSizes: [
          for (final columnID in table.columnIDs.read(ctx))
            table.columns[columnID].whenPresent.width
        ],
        children: [
          for (final columnID in table.columnIDs.read(ctx))
            SizedBox(
              key: ValueKey(columnID),
              width: table.columns[columnID].whenPresent.width.read(ctx),
              child: TableHeaderDropdown(
                ctx: ctx,
                table: table,
                column: table.columns[columnID].whenPresent,
                isOpen: openColumns[columnID].orElse(false),
              ),
            ),
        ],
      ),
      if (ctx.widgetMode == widget.Mode.edit)
        NewColumnButton(
          table: table,
          openColumns: openColumns,
          key: UniqueKey(),
        ),
    ],
  );
}

@reader
Widget _tableHeaderDropdown(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<Table> table,
  required Cursor<pal_table.Column> column,
  required Cursor<bool> isOpen,
}) {
  final textStyle = Theme.of(context).textTheme.bodyLarge;
  const padding = EdgeInsetsDirectional.only(top: 10, bottom: 10, start: 5);
  final dropdownFocus = useFocusNode();

  return DeferredDropdown(
    isOpen: isOpen,
    dropdownFocus: dropdownFocus,
    childAnchor: Alignment.topLeft,
    dropdown: IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide())),
            child: BoundTextFormField(
              column.title,
              ctx: ctx,
              focusNode: dropdownFocus,
              autofocus: true,
              style: textStyle,
              decoration: const InputDecoration(
                focusedBorder: InputBorder.none,
                contentPadding: padding,
              ),
            ),
          ),
          ColumnConfigurationDropdown(ctx: ctx, table: table, column: column),
        ],
      ),
    ),
    child: TextButton(
      style: ButtonStyle(
        padding: MaterialStateProperty.all(padding),
        alignment: Alignment.centerLeft,
      ),
      onPressed:
          ctx.widgetMode == widget.Mode.view || column.id.read(ctx) == table.titleColumn.read(ctx)
              ? null
              : () {
                  isOpen.mut((b) => !b);
                },
      child: Text(
        column.title.read(ctx),
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

@reader
Widget _columnConfigurationDropdown(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<Table> table,
  required Cursor<pal_table.Column> column,
}) {
  final focusForImpl = useMemoized(() {
    final foci = <String, FocusNode>{};
    return (Cursor<pal.Value> impl, Ctx ctx) {
      return foci.putIfAbsent(tableDataGetName(ctx, impl), () => FocusNode());
    };
  });

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButtonDropdown(
        childAnchor: Alignment.topRight,
        dropdownAnchor: Alignment.topLeft,
        dropdownFocus: focusForImpl(column.dataImpl, ctx),
        dropdown: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final type in columnTypes)
                TextButton(
                  key: ValueKey(type),
                  focusNode: focusForImpl(Cursor(type), ctx),
                  onPressed: () => column.setType(type),
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
        child: const Row(
          children: [Icon(Icons.list), Text('Column type')],
        ),
      ),
      ...columnSpecificConfiguration(context, column, ctx: ctx),
      if (column.id.read(ctx) != table.titleColumn.read(ctx))
        TextButton(
          onPressed: () {
            final idToDelete = column.id.read(Ctx.empty);
            table.columns.remove(idToDelete);
            table.columnIDs.remove(
              table.columnIDs.read(Ctx.empty).indexWhere((id) => id == idToDelete)!,
            );
          },
          child: const Row(
            children: [Icon(Icons.delete), Text('Delete column')],
          ),
        ),
    ],
  );
}

Optional<Widget> columnSpecificConfiguration(
  BuildContext context,
  Cursor<pal_table.Column> column, {
  required Ctx ctx,
}) {
  final palImpl = pal.findImpl(
    ctx,
    tableDataDef.asType(
      {tableDataImplementerID: column.dataImpl.type.read(ctx)},
    ),
  )!;
  final getConfig = palImpl.interfaceAccess(ctx, tableDataGetConfigID);
  final currentType = column.dataImpl.type.read(ctx);
  return getConfig.callFn(
    ctx,
    Dict({
      'column': column,
      'impl': column.dataImpl
          .thenOpt<pal.Value>(OptLens(
            const Vec([]),
            (t) => t.type.assignableTo(ctx, currentType) ? Optional(t) : const Optional.none(),
            (t, f) => f(t),
          ))
          .value,
    }),
  ) as Optional<Widget>;
}

@reader
Widget _newColumnButton({
  Cursor<Table>? table,
  Cursor<Dict<ColumnID, bool>>? openColumns,
}) {
  return ElevatedButton(
    onPressed: () {
      final columnID = table?.addColumn(textTableData);
      if (columnID != null) {
        openColumns?[columnID] = true;
      }
    },
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(Icons.add), Text('New column')],
    ),
  );
}
