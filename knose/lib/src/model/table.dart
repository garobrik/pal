import 'package:ctx/ctx.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
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

final tableIDDef = pal.DataDef.unit('TableID');

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
        impl: textColumn,
        title: 'Title',
      ),
      Column(
        impl: booleanColumn,
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
      final column = Column(impl: columnImpl);

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
  final pal.Value impl;
  @override
  final double width;
  @override
  final String title;

  Column({
    ColumnID? id,
    required this.impl,
    this.width = 100,
    this.title = '',
  }) : this.id = id ?? ColumnID();
}

extension ColumnMutations on Cursor<Column> {
  void setType(pal.Value newImpl) {
    if (newImpl != impl.read(Ctx.empty)) {
      this.impl.set(newImpl);
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
  Cursor<Object>? value(Ctx ctx) {
    final rowCtx = ctx.get<_RowCtx>();
    if (rowCtx == null) return null;
    final rowID = rowCtx.rowID;
    final table = ctx.db.get(tableID);
    final column = table.whenPresent.columns[columnID].whenPresent;
    final palImpl = pal.findImpl(
      ctx,
      columnImplDef.asType({columnImplImplementerID: column.impl.type.read(ctx)}),
    );
    final getData = palImpl!.interfaceAccess(ctx, columnImplGetDataID);
    return getData.callFn(ctx, Dict({'rowID': rowID, 'impl': column.impl})) as Cursor<Object>;
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
      columnImplDef.asType({columnImplImplementerID: column.impl.type.read(ctx)}),
    );
    return palImpl!
        .interfaceAccess(ctx, columnImplDataTypeID)
        .callFn(ctx, column.impl.value.read(ctx)) as pal.Type;
  }
}

pal.Value valueColumn(
  pal.Type valueType,
  Widget Function(Ctx ctx, Object rowData) getWidget,
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
  pal.Member(id: valueColumnTypeID, name: 'valueType', type: pal.type),
  pal.Member(
    id: valueColumnValuesID,
    name: 'values',
    type: pal.Map(rowIDDef.asType(), pal.RecordAccess(valueColumnTypeID)),
  ),
  pal.Member(
    id: valueColumnGetWidgetID,
    name: 'getWidget',
    type: pal.FnType(
      returnType: widget.flutterWidgetDef.asType(),
      target: pal.cursorType(pal.RecordAccess(valueColumnTypeID)),
    ),
  ),
]);

final valueColumnImpl = pal.Impl(
  implemented: columnImplDef.asType({columnImplImplementerID: valueColumnDef.asType()}),
  implementations: Dict({
    columnImplDataTypeID: pal.FnExpr(
      pal.FnType(target: valueColumnDef.asType(), returnType: pal.type),
      pal.Literal(pal.type, pal.optionType(pal.RecordAccess(valueColumnTypeID, target: pal.fnArg))),
    ),
    columnImplGetNameID: pal.Literal(
      columnImplGetNameType,
      (Ctx ctx, Object arg) =>
          '${(arg as Cursor<Object>).palValue().recordAccess(valueColumnTypeID).read(ctx)} Column',
    ),
    columnImplGetDataID: pal.Literal(
      columnImplGetDataType,
      (Ctx ctx, Object arg) {
        final colImpl = arg.mapAccess('impl').unwrap! as Cursor<Object>;
        final rowID = arg.mapAccess('rowID').unwrap! as RowID;
        final valueMap = colImpl.palValue().recordAccess(valueColumnValuesID);
        return valueMap.mapAccess(rowID).upcast<Object>();
      },
    ),
    columnImplGetWidgetID: pal.Literal(
      columnImplGetWidgetType,
      (Ctx ctx, Object args) {
        final impl = args.mapAccess('impl').unwrap! as Cursor<Object>;
        final getWidget = impl.palValue().recordAccess(valueColumnGetWidgetID).read(ctx);
        return getWidget.callFn(ctx, args.mapAccess('rowData').unwrap!);
      },
    ),
    columnImplGetConfigID: pal.Literal(
      columnImplGetConfigType,
      (Ctx _, Object __) => const Optional<Widget>.none(),
    ),
  }),
);

final textColumn =
    valueColumn(pal.text, (ctx, obj) => StringField(obj as Cursor<Object>, ctx: ctx));
final numberColumn =
    valueColumn(pal.number, (ctx, obj) => NumField(obj as Cursor<Object>, ctx: ctx));
final booleanColumn =
    valueColumn(pal.boolean, (ctx, obj) => BoolCell(obj as Cursor<Object>, ctx: ctx));
final dataColumn = pal.Value(
  dataColumnDef.asType(),
  Dict({dataColumnTypeID: pal.text, dataColumnValuesID: const Dict<Object, Object>()}),
);

final dataColumnTypeID = pal.MemberID();
final dataColumnValuesID = pal.MemberID();
final dataColumnDef = pal.DataDef.record(
  name: 'DataColumn',
  members: [
    pal.Member(id: dataColumnTypeID, name: 'valueType', type: pal.type),
    pal.Member(
      id: dataColumnValuesID,
      name: 'values',
      type: pal.Map(rowIDDef.asType(), pal.RecordAccess(dataColumnTypeID)),
    ),
  ],
);

final dataColumnImpl = pal.Impl(
  implemented: columnImplDef.asType({columnImplImplementerID: dataColumnDef.asType()}),
  implementations: Dict({
    columnImplDataTypeID: pal.FnExpr(
      pal.FnType(target: dataColumnDef.asType(), returnType: pal.type),
      pal.Literal(pal.type, pal.optionType(pal.RecordAccess(dataColumnTypeID, target: pal.fnArg))),
    ),
    columnImplGetNameID: pal.Literal(
      columnImplGetNameType,
      (Ctx _, Object __) => 'Data Column',
    ),
    columnImplGetDataID: pal.Literal(
      columnImplGetDataType,
      (Ctx ctx, Object arg) {
        final colImpl = arg.mapAccess('impl').unwrap! as Cursor<Object>;
        final rowID = arg.mapAccess('rowID').unwrap! as RowID;
        final valueMap = colImpl.palValue().recordAccess(dataColumnValuesID);
        return valueMap.mapAccess(rowID).upcast<Object>();
      },
    ),
    columnImplGetWidgetID: pal.Literal(
      columnImplGetWidgetType,
      (Ctx ctx, Object args) {
        return ReaderWidget(
          ctx: ctx,
          builder: (_, ctx) {
            final colImpl = args.mapAccess('impl').unwrap! as Cursor<Object>;
            final type = colImpl.palValue().recordAccess(dataColumnTypeID).read(ctx) as pal.Type;
            final value =
                (args.mapAccess('rowData').unwrap! as Cursor<Object>).wrap(pal.optionType(type));
            return DataCell(value: value, enabled: true, ctx: ctx);
          },
        );
      },
    ),
    columnImplGetConfigID: pal.Literal(
      columnImplGetConfigType,
      (Ctx ctx, Object arg) {
        return Optional(TypeSelector(
          // TODO: this is slightly incorrect, doesn't trigger change notif on the row data
          (arg as Cursor<Object>).then(
            Lens(
              [
                Vec(['[]', dataColumnTypeID])
              ],
              (impl) => impl.recordAccess(dataColumnTypeID),
              (impl, fn) {
                final oldType = impl.recordAccess(dataColumnTypeID);
                final newType = fn(oldType);
                if (oldType == newType) {
                  return impl;
                } else {
                  return (impl as Dict<pal.MemberID, Object>)
                      .put(dataColumnTypeID, newType)
                      .put(dataColumnValuesID, const Dict<Object, Object>());
                }
              },
            ),
          ),
          ctx: ctx,
          topLevel: true,
        ));
      },
    ),
  }),
);

final tableDef = pal.InterfaceDef(name: 'Table', members: []);
final columnIDDef = pal.InterfaceDef(name: 'ColumnID', members: []);
final rowIDDef = pal.InterfaceDef(name: 'RowID', members: []);

final columnImplImplementerID = pal.MemberID();
final columnImplDataTypeID = pal.MemberID();
final columnImplGetDataID = pal.MemberID();
final columnImplGetWidgetID = pal.MemberID();
final columnImplGetNameID = pal.MemberID();
final columnImplGetConfigID = pal.MemberID();
final columnImpl = pal.InterfaceType(id: pal.InterfaceID.create());
final columnImplGetNameType = pal.FnType(
    returnType: pal.text,
    target: pal.cursorType(pal.InterfaceAccess(member: columnImplImplementerID)));
final columnImplGetDataType = pal.FnType(
  returnType: pal.cursorType(
    pal.InterfaceAccess(member: columnImplDataTypeID),
  ),
  target: pal.Value(
    const pal.Map(pal.text, pal.type),
    Dict({
      'rowID': rowIDDef.asType(),
      'impl': pal.cursorType(pal.InterfaceAccess(member: columnImplImplementerID))
    }),
  ),
);
final columnImplGetWidgetType = pal.FnType(
  returnType: widget.flutterWidgetDef.asType(),
  target: pal.Value(
    const pal.Map(pal.text, pal.type),
    Dict({
      'rowData': pal.cursorType(
        pal.InterfaceAccess(member: columnImplDataTypeID),
      ),
      'impl': pal.cursorType(pal.InterfaceAccess(member: columnImplImplementerID)),
    }),
  ),
);

final columnImplGetConfigType = pal.FnType(
  returnType: pal.optionType(widget.flutterWidgetDef.asType()),
  target: pal.cursorType(pal.InterfaceAccess(member: columnImplImplementerID)),
);

String columnImplGetName(Ctx ctx, Cursor<pal.Value> impl) {
  final palImpl = pal.findImpl(
    ctx,
    columnImplDef.asType({columnImplImplementerID: impl.type.read(ctx)}),
  )!;
  return palImpl.interfaceAccess(ctx, columnImplGetNameID).callFn(ctx, impl) as String;
}

final columnImplDef = pal.InterfaceDef(
  id: columnImpl.id,
  name: 'ColumnImpl',
  members: [
    pal.Member(id: columnImplImplementerID, name: 'implementer', type: pal.type),
    pal.Member(id: columnImplDataTypeID, name: 'dataType', type: pal.type),
    pal.Member(id: columnImplGetNameID, name: 'getName', type: columnImplGetNameType),
    pal.Member(id: columnImplGetDataID, name: 'getData', type: columnImplGetDataType),
    pal.Member(id: columnImplGetWidgetID, name: 'getWidget', type: columnImplGetWidgetType),
    pal.Member(id: columnImplGetConfigID, name: 'getConfig', type: columnImplGetConfigType),
  ],
);

final tableDB = () {
  final db = Cursor(const pal.DB());
  for (final dataDef in _dataTypes) {
    db.update(dataDef.id, dataDef);
  }
  for (final interface in _interfaceTypes) {
    db.update(interface.id, interface);
  }
  for (final impl in _implementations) {
    db.update(impl.id, impl);
  }

  return db.read(Ctx.empty);
}();

final _dataTypes = [
  valueColumnDef,
  dataColumnDef,
];
final _interfaceTypes = [
  columnImplDef,
];
final _implementations = [
  valueColumnImpl,
  dataColumnImpl,
];
