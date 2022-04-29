import 'package:ctx/ctx.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/table.dart';
import 'package:knose/model.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/uuid.dart';
import 'package:knose/widget.dart' as widget;

part 'core.g.dart';

class TableID extends pal.ID<Table> {
  static const namespace = 'table';

  TableID.create() : super.create(namespace: namespace);
  TableID.from(String key) : super.from(namespace, key);
}

final tableIDDef = pal.DataDef.unit('TableID');
final columnIDDef = pal.DataDef.unit('ColumnID');
final rowIDDef = pal.DataDef.unit('RowID');

class ColumnID extends UUID<ColumnID> {}

class RowID extends UUID<RowID> {}

class TagID extends UUID<TagID> {}

@immutable
@reify
class Table with _TableMixin {
  @override
  final TableID id;
  @override
  final String title;
  @override
  final Dict<ColumnID, Column> columns;
  @override
  final Vec<ColumnID> columnIDs;
  @override
  final ColumnID titleColumn;
  @override
  final Vec<RowID> rowIDs;
  @override
  final Vec<widget.RootID> rowViews;

  Table({
    TableID? id,
    this.columns = const Dict(),
    this.title = '',
    this.columnIDs = const Vec(),
    ColumnID? titleColumn,
    this.rowIDs = const Vec(),
    this.rowViews = const Vec(),
  })  : this.id = id ?? TableID.create(),
        this.titleColumn = titleColumn ?? ColumnID();

  static Table newDefault() {
    final titleColumn = ColumnID();

    final columns = [
      Column(
        id: titleColumn,
        dataImpl: textTableData,
        title: 'Title',
      ),
      Column(
        dataImpl: booleanTableData,
        title: 'Done',
      ),
    ];

    return Table(
      columns: Dict({for (final column in columns) column.id: column}),
      columnIDs: Vec([for (final column in columns) column.id]),
      titleColumn: titleColumn,
      title: 'Untitled table',
    );
  }
}

extension TableComputations on GetCursor<Table> {
  GetCursor<int> get length => rowIDs.length;
}

extension TableMutations on Cursor<Table> {
  void addRow([int? index]) => rowIDs.insert(index ?? rowIDs.length.read(Ctx.empty), RowID());

  ColumnID addColumn(pal.Value columnImpl, [int? index]) {
    late final ColumnID columnID;
    atomically((table) {
      final column = Column(dataImpl: columnImpl);

      table.columns[column.id] = Optional(column);
      table.columnIDs.insert(index ?? table.columnIDs.length.read(Ctx.empty), column.id);

      columnID = column.id;
    });
    return columnID;
  }

  void removeColumn(ColumnID id) {
    columns.remove(id);
    for (final indexedValue in columnIDs.indexedValues(Ctx.empty)) {
      if (indexedValue.value.read(Ctx.empty) == id) {
        columnIDs.remove(indexedValue.index);
        return;
      }
    }
  }
}

@immutable
@reify
class Column with _ColumnMixin {
  @override
  final ColumnID id;
  @override
  final pal.Value dataImpl;
  @override
  final Dict<RowID, Object> data;
  @override
  final double width;
  @override
  final String title;

  Column({
    ColumnID? id,
    required this.dataImpl,
    this.data = const Dict<RowID, Object>(),
    this.width = 100,
    this.title = '',
  }) : this.id = id ?? ColumnID();
}

extension ColumnMutations on Cursor<Column> {
  void setType(pal.Value newDataImpl) {
    if (newDataImpl != dataImpl.read(Ctx.empty)) {
      this.dataImpl.set(newDataImpl);
      this.data.set(const Dict<RowID, Object>());
    }
  }
}

@immutable
class _TableDataSource extends DataSource {
  final Cursor<Table> table;

  _TableDataSource(this.table);

  @override
  late final GetCursor<Vec<Datum>> data = GetCursor.compute((ctx) {
    final columns = table.columnIDs.read(ctx);
    return Vec([for (final column in columns) _TableDatum(table.id.read(ctx), column)]);
  }, ctx: Ctx.empty);
}

extension TableCtxExtension on Ctx {
  Ctx withTable(Cursor<Table> table) => withElement(_TableDataSource(table));
  Ctx withRow(RowID rowID) => withElement(_RowCtx(rowID));
}

class _RowCtx extends CtxElement {
  final RowID rowID;

  _RowCtx(this.rowID);
}

@immutable
class _TableDatum extends Datum {
  final TableID tableID;
  final ColumnID columnID;

  const _TableDatum(this.tableID, this.columnID);

  @override
  Cursor<Object>? value(Ctx ctx) {
    final rowCtx = ctx.get<_RowCtx>();
    if (rowCtx == null) return null;
    final rowID = rowCtx.rowID;
    final table = ctx.db.get(tableID);
    final column = table.whenPresent.columns[columnID].whenPresent;
    final palImpl = pal.findImpl(
      ctx,
      tableDataDef.asType({tableDataImplementerID: column.dataImpl.type.read(ctx)}),
    );
    final getData = palImpl!.interfaceAccess(ctx, tableDataGetDefaultID);
    final defaultData = getData.callFn(ctx, column.dataImpl.value);
    return column.data[rowID].orElse(defaultData);
  }

  @override
  String name(Ctx ctx) {
    final table = ctx.db.get(tableID);
    return table.whenPresent.columns[columnID].whenPresent.title.read(ctx);
  }

  @override
  pal.Type type(Ctx ctx) {
    final column = ctx.db.get(tableID).whenPresent.columns[columnID].whenPresent;
    final palImpl = pal.findImpl(
      ctx,
      tableDataDef.asType({tableDataImplementerID: column.dataImpl.type.read(ctx)}),
    );
    return palImpl!.interfaceAccess(ctx, tableDataGetTypeID).callFn(ctx, column.dataImpl.value)
        as pal.Type;
  }
}

final tableDataImplementerID = pal.MemberID();
final tableDataGetNameID = pal.MemberID();
final tableDataGetTypeID = pal.MemberID();
final tableDataGetDefaultID = pal.MemberID();
final tableDataGetWidgetID = pal.MemberID();
final tableDataGetConfigID = pal.MemberID();
final tableData = pal.InterfaceType(id: pal.InterfaceID.create());
final tableDataGetNameType = pal.FnType(
  returnType: pal.text,
  target: pal.cursorType(pal.InterfaceAccess(member: tableDataImplementerID)),
);
final tableDataGetTypeType = pal.FnType(
  returnType: pal.type,
  target: pal.cursorType(pal.InterfaceAccess(member: tableDataImplementerID)),
);
final tableDataGetDefaultType = pal.FnType(
  returnType: pal.InterfaceAccess(member: tableDataGetTypeID),
  target: pal.cursorType(pal.InterfaceAccess(member: tableDataImplementerID)),
);
final tableDataGetWidgetType = pal.FnType(
  returnType: widget.flutterWidgetDef.asType(),
  target: pal.Value(
    const pal.Map(pal.text, pal.type),
    Dict({
      'data': pal.cursorType(pal.InterfaceAccess(member: tableDataGetTypeID)),
      'impl': pal.cursorType(pal.InterfaceAccess(member: tableDataImplementerID)),
    }),
  ),
);

final tableDataGetConfigType = pal.FnType(
  returnType: pal.optionType(widget.flutterWidgetDef.asType()),
  target: pal.cursorType(pal.InterfaceAccess(member: tableDataImplementerID)),
);

String tableDataGetName(Ctx ctx, Cursor<pal.Value> impl) {
  final palImpl = pal.findImpl(
    ctx,
    tableDataDef.asType({tableDataImplementerID: impl.type.read(ctx)}),
  )!;
  return palImpl.interfaceAccess(ctx, tableDataGetNameID).callFn(ctx, impl.value) as String;
}

final tableDataDef = pal.InterfaceDef(
  id: tableData.id,
  name: 'ColumnImpl',
  members: [
    pal.Member(id: tableDataImplementerID, name: 'implementer', type: pal.type),
    pal.Member(id: tableDataGetNameID, name: 'getName', type: tableDataGetNameType),
    pal.Member(id: tableDataGetTypeID, name: 'getType', type: tableDataGetTypeType),
    pal.Member(id: tableDataGetDefaultID, name: 'getDefault', type: tableDataGetDefaultType),
    pal.Member(id: tableDataGetWidgetID, name: 'getWidget', type: tableDataGetWidgetType),
    pal.Member(id: tableDataGetConfigID, name: 'getConfig', type: tableDataGetConfigType),
  ],
);
