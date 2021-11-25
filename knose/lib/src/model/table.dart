import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';

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
        type: textType,
        title: 'Title',
      ),
      Column(
        id: ColumnID(),
        type: booleanType,
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

  ColumnID addColumn([int? index]) {
    late final ColumnID columnID;
    atomically((table) {
      final column = Column(type: textType);

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
  final PalType type;
  @override
  final Dict<RowID, PalValue> values;
  @override
  final Object? columnConfig;
  @override
  final double width;
  @override
  final String title;

  Column({
    ColumnID? id,
    required this.type,
    this.values = const Dict(),
    this.width = 100,
    this.title = '',
    this.columnConfig,
  }) : this.id = id ?? ColumnID();
}

extension ColumnMutations on Cursor<Column> {
  void setType(PalType type) {
    if (type != this.type.read(Ctx.empty)) {
      this.values.set(const Dict());
      this.type.set(type);
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
@reify
class _TableDatum extends Datum with _TableDatumMixin {
  @override
  final TableID tableID;
  @override
  final ColumnID columnID;

  _TableDatum(this.tableID, this.columnID);

  @override
  Cursor<PalValue>? build(Ctx ctx) {
    final rowCtx = ctx.get<_RowCtx>();
    if (rowCtx == null) return null;
    final rowID = rowCtx.rowID;
    final table = ctx.db.get(tableID);
    final column = table.whenPresent.columns[columnID].whenPresent;
    return column.values[rowID].partial(
      to: (opt) => PalValue(type(ctx), opt),
      from: (diff) => DiffResult(diff.value.value as Optional<PalValue>, diff.diff),
    );
  }

  @override
  String name(Ctx ctx) {
    final table = ctx.db.get(tableID);
    return table.whenPresent.columns[columnID].whenPresent.title.read(ctx);
  }

  @override
  PalType type(Ctx ctx) {
    final table = ctx.db.get(tableID);
    final colType = table.whenPresent.columns[columnID].whenPresent.type.read(ctx);
    return optionDef.asType({optionMemberID: colType});
  }
}
