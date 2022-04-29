import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide Table, TableRow;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/widget.dart' as widget;
import 'package:knose/table.dart' hide Column;
import 'package:knose/table.dart' as table;
import 'package:knose/pal.dart' as pal;

part 'link_data.g.dart';

final linkTableData = pal.Value(
  linkTableDataDef.asType(),
  linkTableDataDef.instantiate({
    linkTableDataTableID: const Optional<Object>.none(),
    linkTableDataColumnID: const Optional<Object>.none(),
  }),
);

final linkTableDataTableID = pal.MemberID();
final linkTableDataColumnID = pal.MemberID();
final linkTableDataDef = pal.DataDef.record(name: 'ListTableData', members: [
  pal.Member(id: linkTableDataTableID, name: 'table', type: pal.optionType(tableIDDef.asType())),
  pal.Member(id: linkTableDataColumnID, name: 'column', type: pal.optionType(columnIDDef.asType())),
]);

final rowRefTableID = pal.MemberID();
final rowRefRowID = pal.MemberID();
final rowRefDef = pal.DataDef.record(name: 'RowRef', members: [
  // pal.Member(id: rowRefTableID, name: 'table', type: tableIDDef.asType()),
  pal.Member(id: rowRefRowID, name: 'row', type: pal.optionType(rowIDDef.asType())),
]);

final linkTableDataImpl = pal.Impl(
  implemented: tableDataDef.asType({tableDataImplementerID: linkTableDataDef.asType()}),
  implementations: Dict({
    tableDataGetTypeID: pal.Literal(
      tableDataGetTypeType,
      (Ctx ctx, Object arg) {
        final impl = arg as GetCursor<Object>;
        final tableID = impl.recordAccess(linkTableDataTableID).read(ctx) as Optional<TableID>;
        if (tableID.isEmpty) return pal.unit;

        final table = ctx.db.get(tableID.unwrap!).whenPresent;

        final columnID = impl.recordAccess(linkTableDataColumnID).read(ctx) as Optional<ColumnID>;
        if (columnID.isEmpty) return rowRefDef.asType();

        final columnData = table.columns[columnID.unwrap!].whenPresent.dataImpl;
        final columnDataImpl = pal.findImpl(
          ctx,
          tableDataDef.asType({tableDataImplementerID: columnData.palType().read(ctx)}),
        )!;

        return columnDataImpl
            .interfaceAccess(ctx, tableDataGetTypeID)
            .callFn(ctx, columnDataImpl.palValue());
      },
    ),
    tableDataGetNameID: pal.Literal(
      tableDataGetNameType,
      (Ctx _, Object __) => 'Link',
    ),
    tableDataGetDefaultID: pal.Literal(
      tableDataGetDefaultType,
      (Ctx _, Object __) => rowRefDef.instantiate({rowRefRowID: const Optional<Object>.none()}),
    ),
    tableDataGetWidgetID: pal.Literal(
      tableDataGetWidgetType,
      (Ctx ctx, Object args) {
        final impl = (args.mapAccess('impl').unwrap! as Cursor<Object>);
        final rowRef = (args.mapAccess('rowData').unwrap! as Cursor<Object>);

        return LinkCell(ctx: ctx, link: rowRef, linkImpl: impl);
      },
    ),
    tableDataGetConfigID: pal.Literal(
      tableDataGetConfigType,
      (Ctx ctx, Object args) {
        final dataImpl = args.mapAccess('impl').unwrap! as Cursor<Object>;
        return Optional(LinkConfig(ctx: ctx, linkImpl: dataImpl));
      },
    ),
  }),
);

@reader
Widget _linkCell({
  required Cursor<Object> link,
  required Cursor<Object> linkImpl,
  required Ctx ctx,
}) {
  final tableID = linkImpl.recordAccess(linkTableDataTableID).read(ctx) as Optional<Object>;

  final child = ReaderWidget(
    ctx: ctx,
    builder: (_, ctx) {
      if (tableID.isEmpty) return Container();
      final table = ctx.db.get(tableID.unwrap! as TableID).whenPresent;

      final rowID = link.recordAccess(rowRefRowID).read(ctx) as Optional<Object>;
      if (rowID.isEmpty) return Container();

      final titleColumn = table.columns[table.titleColumn.read(ctx)].whenPresent;

      return Text(titleColumn.data[rowID.unwrap! as RowID].orElse('').read(ctx) as String);
    },
  );

  final dropdownFocus = useFocusNode();

  return CellDropdown(
    constrainHeight: false,
    constrainWidth: false,
    ctx: tableID.isEmpty ? ctx.withWidgetMode(widget.Mode.view) : ctx,
    expands: true,
    dropdownFocus: dropdownFocus,
    dropdown: ReaderWidget(
      ctx: ctx.withWidgetMode(widget.Mode.view),
      builder: (_, ctx) {
        final table = ctx.db.get(tableID.unwrap! as TableID).whenPresent;

        return Column(
          children: [
            TableHeader(table, ctx: ctx),
            for (final rowID in table.rowIDs.read(ctx))
              TextButton(
                style: ButtonStyle(padding: MaterialStateProperty.all(EdgeInsets.zero)),
                focusNode: rowID == table.rowIDs.read(ctx).first ? dropdownFocus : null,
                onPressed: () => link.recordAccess(rowRefRowID).set(Optional(rowID)),
                child: TableRow(ctx: ctx, table: table, rowID: rowID),
              )
          ],
        );
      },
    ),
    child: child,
  );
}

@reader
Widget _linkConfig({
  required Cursor<Object> linkImpl,
  required Ctx ctx,
}) {
  final tableID = linkImpl.recordAccess(linkTableDataTableID).read(ctx) as Optional<Object>;
  late final Optional<Cursor<Object>> tableRootInstance;
  if (tableID.isEmpty) {
    tableRootInstance = const Optional.none();
  } else {
    tableRootInstance = _tableInstance(ctx, tableID.unwrap! as TableID);
  }

  final tableName = tableRootInstance
      .map((t) => t.recordAccess(widget.rootNameID).read(ctx) as String)
      .orElse('None');

  final tables = ctx.db.cache[TableID.namespace].whenPresent.keys.read(ctx).map(
        (key) =>
            ctx.db.cache[TableID.namespace].whenPresent[key].whenPresent.cast<Table>().id.read(ctx),
      );

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DropdownMenu<TableID>(
        childAnchor: Alignment.topRight,
        items: tables,
        buildItem: (itemID) {
          return Text(
            _tableInstance(ctx, itemID)
                .unwrap!
                .recordAccess(widget.rootNameID)
                .read(ctx)
                .toString(),
          );
        },
        currentItem: (tableID.unwrap ?? tables.first) as TableID,
        onItemSelected: (newID) => linkImpl.recordAccess(linkTableDataTableID).set(Optional(newID)),
        child: Text('Table: $tableName'),
      )
    ],
  );
}

Optional<Cursor<Object>> _tableInstance(Ctx ctx, TableID tableID) {
  return ctx.db.find<Object>(
    ctx: ctx,
    namespace: widget.RootID.namespace,
    predicate: (root) {
      final instance = root.recordAccess(widget.rootInstanceID);
      if (!identical(instance.recordAccess(widget.instanceWidgetID).read(ctx), tableWidget)) {
        return false;
      }
      return instance.recordAccess(widget.instanceDataID).recordAccess(tableRefIDID).read(ctx) ==
          tableID;
    },
  );
}
