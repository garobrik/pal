import 'package:ctx/ctx.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';

import 'package:knose/model.dart';

part 'table.g.dart';

class TableID extends PalID<Table> {
  static const namespace = 'table';

  TableID.create() : super.create(namespace: namespace);
  TableID.from(String key) : super.from(namespace, key);
}

class ColumnID extends UUID<ColumnID> {}

class RowID extends UUID<RowID> {}

class TagID extends UUID<TagID> {}

class RowViewID extends UUID<RowViewID> {}

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
  final Vec<WidgetID> rowViews;

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
        columnImpl: textColumn,
        title: 'Title',
      ),
      Column(
        columnImpl: booleanColumn,
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

  ColumnID addColumn(PalValue columnImpl, [int? index]) {
    late final ColumnID columnID;
    atomically((table) {
      final column = Column(columnImpl: columnImpl);

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
  final Object columnImpl;
  @override
  final double width;
  @override
  final String title;

  Column({
    ColumnID? id,
    required this.columnImpl,
    this.width = 100,
    this.title = '',
  }) : this.id = id ?? ColumnID();
}

extension ColumnMutations on Cursor<Column> {
  void setType(PalValue newColumnType) {
    if (newColumnType != columnImpl.read(Ctx.empty)) {
      this.columnImpl.set(newColumnType);
    }
  }
}

// @ReifiedLens(cases: [
//   SelectColumn,
//   MultiselectColumn,
//   LinkColumn,
// ])
// abstract class ColumnRows {
//   const ColumnRows();
// }

// @immutable
// @reify
// class SelectColumn extends ColumnRows with _SelectColumnMixin {
//   @override
//   final Dict<TagID, Tag> tags;
//   @override
//   final Dict<RowID, TagID> values;

//   const SelectColumn({
//     this.tags = const Dict(),
//     this.values = const Dict(),
//   });
// }

// extension SelectColumnMutations on Cursor<SelectColumn> {
//   TagID addTag(Tag tag) {
//     tags[tag.id] = Optional(tag);
//     return tag.id;
//   }
// }

// extension MultiselectColumnMutations on Cursor<MultiselectColumn> {
//   TagID addTag(Tag tag) {
//     tags[tag.id] = Optional(tag);
//     return tag.id;
//   }
// }

// @immutable
// @reify
// class Tag with _TagMixin {
//   @override
//   final TagID id;
//   @override
//   final String name;
//   @override
//   final flutter.Color color;

//   Tag({TagID? id, required this.name, required this.color}) : this.id = id ?? TagID();
// }

// @immutable
// @reify
// class MultiselectColumn extends ColumnRows with _MultiselectColumnMixin {
//   @override
//   final Dict<TagID, Tag> tags;
//   @override
//   final Dict<RowID, CSet<TagID>> values;

//   const MultiselectColumn({
//     this.tags = const Dict(),
//     this.values = const Dict(),
//   });
// }

// @immutable
// @reify
// class LinkColumn extends ColumnRows with _LinkColumnMixin {
//   @override
//   final NodeID<Table>? table;
//   @override
//   final Dict<RowID, RowID> values;

//   const LinkColumn({
//     this.values = const Dict(),
//     this.table,
//   });
// }

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
  Cursor<Object>? build(Ctx ctx) {
    final rowCtx = ctx.get<_RowCtx>();
    if (rowCtx == null) return null;
    final rowID = rowCtx.rowID;
    final table = ctx.db.get(tableID);
    final column = table.whenPresent.columns[columnID].whenPresent;
    final getData = column.columnImpl
        .interfaceAccess(ctx, columnImplDef.asType(), columnImplGetDataID) as ColumnGetDataFn;
    return getData(Dict({'rowID': rowID, 'impl': column.columnImpl}), ctx: ctx);
  }

  @override
  String name(Ctx ctx) {
    final table = ctx.db.get(tableID);
    return table.whenPresent.columns[columnID].whenPresent.title.read(ctx);
  }

  @override
  PalType type(Ctx ctx) {
    return ctx.db
        .get(tableID)
        .whenPresent
        .columns[columnID]
        .whenPresent
        .columnImpl
        .interfaceAccess(ctx, columnImplDef.asType(), columnImplDataID) as PalType;
  }
}

PalValue valueColumn(
  PalType valueType,
  Widget Function(Cursor<Object> rowData, {required Ctx ctx}) getWidget,
) {
  return PalValue(
    valueColumnDef.asType(),
    Dict({
      valueColumnTypeID: valueType,
      valueColumnValuesID: const Dict<Object, Object>(),
      valueColumnGetWidgetID: getWidget,
    }),
  );
}

final valueColumnTypeID = MemberID();
final valueColumnValuesID = MemberID();
final valueColumnGetWidgetID = MemberID();
final valueColumnGetWidgetType = MemberID();
final valueColumnDef = DataDef.record(name: 'ValueColumn', members: [
  PalMember(id: valueColumnTypeID, name: 'valueType', type: typeType),
  PalMember(
    id: valueColumnValuesID,
    name: 'values',
    type: MapType(rowIDDef.asType(), RecordAccess(valueColumnTypeID)),
  ),
  PalMember(
    id: valueColumnGetWidgetID,
    name: 'getWidget',
    type: FunctionType(
      returnType: flutterWidgetDef.asType(),
      target: cursorType(RecordAccess(valueColumnTypeID)),
    ),
  ),
]);

final valueColumnImpl = PalImpl(
  implementer: valueColumnDef.asType(),
  implemented: columnImplDef.asType(),
  implementations: {
    columnImplDataID: PalValue(typeType, optionType(RecordAccess(valueColumnTypeID))),
    columnImplGetNameID: PalValue(
      columnImplGetNameType,
      (Cursor<PalValue> arg, {required Ctx ctx}) =>
          '${arg.value.recordAccess(valueColumnTypeID).read(ctx).toString()} Column',
    ),
    columnImplGetDataID: PalValue(
      columnImplGetDataType,
      (Dict<String, Object> dict, {required Ctx ctx}) {
        final colImpl = dict['impl'].unwrap! as Cursor<Object>;
        final rowID = dict['rowID'].unwrap! as RowID;
        final valueMap = colImpl.palValue().recordAccess(valueColumnValuesID);
        return valueMap.mapAccess(rowID);
      },
    ),
    columnImplGetWidgetID: PalValue(
      columnImplGetWidgetType,
      (Dict<String, Cursor<Object>> args, {required Ctx ctx}) {
        final impl = args['impl'].unwrap!;
        final getWidget = impl.palValue().recordAccess(valueColumnGetWidgetID).read(ctx) as Widget
            Function(Cursor<Object>, {required Ctx ctx});
        return getWidget(args['rowData'].unwrap!, ctx: ctx);
      },
    ),
  },
);

final textColumn = valueColumn(textType, StringField.new);
final numberColumn = valueColumn(numberType, NumField.new);
final booleanColumn = valueColumn(booleanType, BoolCell.new);
final dataColumn = PalValue(
  dataColumnDef.asType(),
  Dict({dataColumnTypeID: textType, dataColumnValuesID: const Dict<Object, Object>()}),
);

final dataColumnTypeID = MemberID();
final dataColumnValuesID = MemberID();
final dataColumnDef = DataDef.record(
  name: 'DataColumn',
  members: [
    PalMember(id: dataColumnTypeID, name: 'valueType', type: typeType),
    PalMember(
      id: dataColumnValuesID,
      name: 'values',
      type: MapType(rowIDDef.asType(), RecordAccess(dataColumnTypeID)),
    ),
  ],
);

final dataColumnImpl = PalImpl(
  implementer: dataColumnDef.asType(),
  implemented: columnImplDef.asType(),
  implementations: {
    columnImplDataID: RecordAccess(valueColumnTypeID),
    columnImplGetNameID: PalValue(
      columnImplGetNameType,
      (Cursor<PalValue> arg, {required Ctx ctx}) => 'Data Column',
    ),
    columnImplGetDataID: PalValue(
      columnImplGetDataType,
      (Dict<String, Object> dict, {required Ctx ctx}) {
        final colImpl = dict['impl'].unwrap! as Cursor<Object>;
        final rowID = dict['rowID'].unwrap! as RowID;
        final valueMap = colImpl.palValue().recordAccess(dataColumnValuesID);
        return valueMap.mapAccess(rowID);
      },
    ),
    columnImplGetWidgetID: PalValue(
      columnImplGetWidgetType,
      (Dict<String, Cursor<Object>> args, {required Ctx ctx}) {
        return Text(
            args['impl'].unwrap!.palValue().recordAccess(dataColumnTypeID).read(ctx).toString());
      },
    ),
  },
);

final tableDef = InterfaceDef(name: 'Table', members: []);
final columnIDDef = InterfaceDef(name: 'ColumnID', members: []);
final rowIDDef = InterfaceDef(name: 'RowID', members: []);

final columnImplDataID = MemberID();
final columnImplGetDataID = MemberID();
final columnImplGetWidgetID = MemberID();
final columnImplGetNameID = MemberID();
final columnImplType = InterfaceType(id: InterfaceID.create());
final columnImplGetNameType = FunctionType(returnType: textType, target: cursorType(thisType));
final columnImplGetDataType = FunctionType(
  returnType: cursorType(
    InterfaceAccess(member: columnImplDataID, iface: columnImplType),
  ),
  target: PalValue(
    const MapType(textType, typeType),
    Dict({'rowID': rowIDDef.asType(), 'impl': cursorType(thisType)}),
  ),
);
final columnImplGetWidgetType = FunctionType(
  returnType: flutterWidgetDef.asType(),
  target: PalValue(
    const MapType(textType, typeType),
    Dict({
      'rowData': cursorType(
        InterfaceAccess(member: columnImplDataID, iface: columnImplType),
      ),
      'impl': cursorType(thisType),
    }),
  ),
);

final columnImplDef = InterfaceDef(
  id: columnImplType.id,
  name: 'ColumnImpl',
  members: [
    PalMember(id: columnImplDataID, name: 'dataType', type: typeType),
    PalMember(id: columnImplGetNameID, name: 'getName', type: columnImplGetNameType),
    PalMember(id: columnImplGetDataID, name: 'getData', type: columnImplGetDataType),
    PalMember(id: columnImplGetWidgetID, name: 'getWidget', type: columnImplGetWidgetType)
  ],
);

typedef ColumnGetNameFn = String Function(
  Cursor<PalValue> impl, {
  required Ctx ctx,
});

typedef ColumnGetDataFn = Cursor<Object> Function(
  Dict<String, Object>, {
  required Ctx ctx,
});

typedef ColumnGetWidgetFn = Widget Function(
  Dict<String, Cursor<Object>>, {
  required Ctx ctx,
});
