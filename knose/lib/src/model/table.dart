import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/widgets.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';

import 'package:knose/model.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/uuid.dart';
import 'package:knose/widget.dart' as widget;

part 'table.g.dart';

class TableID extends pal.ID<Table> {
  static const namespace = 'table';

  TableID.create() : super.create(namespace: namespace);
  TableID.from(String key) : super.from(namespace, key);
}

final tableIDDef = pal.DataDef(name: 'TableID');

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
  final Vec<widget.ID> rowViews;

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

  ColumnID addColumn(pal.Value columnImpl, [int? index]) {
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
  final pal.Value columnImpl;
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
  void setType(pal.Value newColumnType) {
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
  pal.Type type(Ctx ctx) {
    return ctx.db
        .get(tableID)
        .whenPresent
        .columns[columnID]
        .whenPresent
        .columnImpl
        .interfaceAccess(ctx, columnImplDef.asType(), columnImplDataID) as pal.Type;
  }
}

pal.Value valueColumn(
  pal.Type valueType,
  Widget Function(Cursor<Object> rowData, {required Ctx ctx}) getWidget,
) {
  return pal.Value(
    valueColumnDef.asType(),
    Dict({
      valueColumnTypeID: valueType,
      valueColumnValuesID: const Dict<Object, Object>(),
      valueColumnGetWidgetID: getWidget,
    }),
  );
}

final valueColumnTypeID = pal.MemberID();
final valueColumnValuesID = pal.MemberID();
final valueColumnGetWidgetID = pal.MemberID();
final valueColumnGetWidgetType = pal.MemberID();
final valueColumnDef = pal.DataDef.record(name: 'ValueColumn', members: [
  pal.Member(id: valueColumnTypeID, name: 'valueType', type: pal.typeType),
  pal.Member(
    id: valueColumnValuesID,
    name: 'values',
    type: pal.Map(rowIDDef.asType(), pal.RecordAccess(valueColumnTypeID)),
  ),
  pal.Member(
    id: valueColumnGetWidgetID,
    name: 'getWidget',
    type: pal.FunctionType(
      returnType: widget.flutterWidgetDef.asType(),
      target: pal.cursorType(pal.RecordAccess(valueColumnTypeID)),
    ),
  ),
]);

final valueColumnImpl = pal.Impl(
  implementer: valueColumnDef.asType(),
  implemented: columnImplDef.asType(),
  implementations: {
    columnImplDataID: pal.Value(pal.typeType, pal.optionType(pal.RecordAccess(valueColumnTypeID))),
    columnImplGetNameID: pal.Value(
      columnImplGetNameType,
      (Cursor<pal.Value> arg, {required Ctx ctx}) =>
          '${arg.value.recordAccess(valueColumnTypeID).read(ctx)} Column',
    ),
    columnImplGetDataID: pal.Value(
      columnImplGetDataType,
      (Dict<String, Object> dict, {required Ctx ctx}) {
        final colImpl = dict['impl'].unwrap! as Cursor<Object>;
        final rowID = dict['rowID'].unwrap! as RowID;
        final valueMap = colImpl.palValue().recordAccess(valueColumnValuesID);
        return valueMap.mapAccess(rowID);
      },
    ),
    columnImplGetWidgetID: pal.Value(
      columnImplGetWidgetType,
      (Dict<String, Cursor<Object>> args, {required Ctx ctx}) {
        final impl = args['impl'].unwrap!;
        final getWidget = impl.palValue().recordAccess(valueColumnGetWidgetID).read(ctx) as Widget
            Function(Cursor<Object>, {required Ctx ctx});
        return getWidget(args['rowData'].unwrap!, ctx: ctx);
      },
    ),
    columnImplGetConfigID: pal.Value(
      columnImplGetConfigType,
      (Cursor<pal.Value> arg, {required Ctx ctx}) => const Optional<flutter.Widget>.none(),
    ),
  },
);

final textColumn = valueColumn(pal.text, StringField.new);
final numberColumn = valueColumn(pal.number, NumField.new);
final booleanColumn = valueColumn(pal.boolean, BoolCell.new);
final dataColumn = pal.Value(
  dataColumnDef.asType(),
  Dict({dataColumnTypeID: pal.text, dataColumnValuesID: const Dict<Object, Object>()}),
);

final dataColumnTypeID = pal.MemberID();
final dataColumnValuesID = pal.MemberID();
final dataColumnDef = pal.DataDef.record(
  name: 'DataColumn',
  members: [
    pal.Member(id: dataColumnTypeID, name: 'valueType', type: pal.typeType),
    pal.Member(
      id: dataColumnValuesID,
      name: 'values',
      type: pal.Map(rowIDDef.asType(), pal.RecordAccess(dataColumnTypeID)),
    ),
  ],
);

final dataColumnImpl = pal.Impl(
  implementer: dataColumnDef.asType(),
  implemented: columnImplDef.asType(),
  implementations: {
    columnImplDataID: pal.RecordAccess(valueColumnTypeID),
    columnImplGetNameID: pal.Value(
      columnImplGetNameType,
      (Cursor<pal.Value> arg, {required Ctx ctx}) => 'Data Column',
    ),
    columnImplGetDataID: pal.Value(
      columnImplGetDataType,
      (Dict<String, Object> dict, {required Ctx ctx}) {
        final colImpl = dict['impl'].unwrap! as Cursor<Object>;
        final rowID = dict['rowID'].unwrap! as RowID;
        final valueMap = colImpl.palValue().recordAccess(dataColumnValuesID);
        return valueMap.mapAccess(rowID);
      },
    ),
    columnImplGetWidgetID: pal.Value(
      columnImplGetWidgetType,
      (Dict<String, Cursor<Object>> args, {required Ctx ctx}) {
        return Text(
            args['impl'].unwrap!.palValue().recordAccess(dataColumnTypeID).read(ctx).toString());
      },
    ),
    columnImplGetConfigID: pal.Value(
      columnImplGetConfigType,
      (Cursor<pal.Value> arg, {required Ctx ctx}) {
        final columnType = arg.value.recordAccess(dataColumnTypeID);

        return Optional(ReaderWidget(
          ctx: ctx,
          builder: (_, ctx) => TextButtonDropdown(
            childAnchor: Alignment.topRight,
            dropdown: flutter.Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final type in [pal.text, pal.boolean, pal.number])
                  flutter.TextButton(
                    onPressed: () => columnType.set(type),
                    child: Text(type.toString()),
                  )
              ],
            ),
            child: flutter.Row(children: [Text('Type: ${columnType.read(ctx)}')]),
          ),
        ));
      },
    ),
  },
);

final tableDef = pal.InterfaceDef(name: 'Table', members: []);
final columnIDDef = pal.InterfaceDef(name: 'ColumnID', members: []);
final rowIDDef = pal.InterfaceDef(name: 'RowID', members: []);

final columnImplDataID = pal.MemberID();
final columnImplGetDataID = pal.MemberID();
final columnImplGetWidgetID = pal.MemberID();
final columnImplGetNameID = pal.MemberID();
final columnImplGetConfigID = pal.MemberID();
final columnImplType = pal.InterfaceType(id: pal.InterfaceID.create());
final columnImplGetNameType =
    pal.FunctionType(returnType: pal.text, target: pal.cursorType(pal.thisType));
final columnImplGetDataType = pal.FunctionType(
  returnType: pal.cursorType(
    pal.InterfaceAccess(member: columnImplDataID, iface: columnImplType),
  ),
  target: pal.Value(
    const pal.Map(pal.text, pal.typeType),
    Dict({'rowID': rowIDDef.asType(), 'impl': pal.cursorType(pal.thisType)}),
  ),
);
final columnImplGetWidgetType = pal.FunctionType(
  returnType: widget.flutterWidgetDef.asType(),
  target: pal.Value(
    const pal.Map(pal.text, pal.typeType),
    Dict({
      'rowData': pal.cursorType(
        pal.InterfaceAccess(member: columnImplDataID, iface: columnImplType),
      ),
      'impl': pal.cursorType(pal.thisType),
    }),
  ),
);

final columnImplGetConfigType = pal.FunctionType(
  returnType: pal.optionType(widget.flutterWidgetDef.asType()),
  target: pal.cursorType(pal.thisType),
);

final columnImplDef = pal.InterfaceDef(
  id: columnImplType.id,
  name: 'ColumnImpl',
  members: [
    pal.Member(id: columnImplDataID, name: 'dataType', type: pal.typeType),
    pal.Member(id: columnImplGetNameID, name: 'getName', type: columnImplGetNameType),
    pal.Member(id: columnImplGetDataID, name: 'getData', type: columnImplGetDataType),
    pal.Member(id: columnImplGetWidgetID, name: 'getWidget', type: columnImplGetWidgetType),
    pal.Member(id: columnImplGetConfigID, name: 'getConfig', type: columnImplGetConfigType),
  ],
);

typedef ColumnGetNameFn = String Function(
  Cursor<pal.Value> impl, {
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

typedef ColumnGetConfigFn = Optional<Widget> Function(
  Cursor<pal.Value> impl, {
  required Ctx ctx,
});

final tableDB = () {
  final db = Cursor(const pal.DB());
  for (final interface in _interfaceTypes) {
    db.update(interface.id, interface);
  }
  for (final impl in _implementations) {
    db.update(impl.id, impl);
  }

  return db.read(Ctx.empty);
}();

final _interfaceTypes = [
  columnImplDef,
];
final _implementations = [
  valueColumnImpl,
  dataColumnImpl,
];
