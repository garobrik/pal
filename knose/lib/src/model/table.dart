import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';

import 'package:knose/model.dart' hide List;

part 'table.g.dart';

class ColumnID extends UUID<ColumnID> {}

class RowID extends UUID<RowID> {}

class TagID extends UUID<TagID> {}

class RowViewID extends UUID<RowViewID> {}

@immutable
@reify
class Table with _TableMixin implements TitledNode {
  @override
  final NodeID<Table> id;
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
  final Vec<NodeID<NodeView<TopLevelNodeBuilder>>> rowViews;

  Table({
    NodeID<Table>? id,
    this.columns = const Dict(),
    this.title = '',
    this.columnIDs = const Vec(),
    ColumnID? titleColumn,
    this.rowIDs = const Vec(),
    this.rowViews = const Vec(),
  })  : this.id = id ?? NodeID<Table>(),
        this.titleColumn = titleColumn ?? ColumnID();

  static Table newDefault() {
    final titleColumn = ColumnID();

    final columns = [
      Column(
        id: titleColumn,
        rows: const StringColumn(),
        title: 'Title',
      ),
      Column(
        id: ColumnID(),
        rows: const BooleanColumn(),
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

  @override
  Table mut_title(String title) => copyWith(title: title);
}

extension TableComputations on GetCursor<Table> {
  GetCursor<int> get length => rowIDs.length;
}

extension TableMutations on Cursor<Table> {
  void addRow([int? index]) => rowIDs.insert(index ?? rowIDs.length.read(null), RowID());

  ColumnID addColumn([int? index]) {
    late final ColumnID columnID;
    atomically((table) {
      final column = Column(rows: const StringColumn());

      table.columns[column.id] = Optional(column);
      table.columnIDs.insert(index ?? table.columnIDs.length.read(null), column.id);

      columnID = column.id;
    });
    return columnID;
  }

  void removeColumn(ColumnID id) {
    columns.remove(id);
    for (final indexedValue in columnIDs.indexedValues(null)) {
      if (indexedValue.value.read(null) == id) {
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
  final ColumnRows rows;
  @override
  final double width;
  @override
  final String title;

  Column({
    ColumnID? id,
    required this.rows,
    this.width = 100,
    this.title = '',
  }) : this.id = id ?? ColumnID();
}

extension ColumnMutations on Cursor<Column> {
  void setType(ColumnRowsCase caze) {
    rows.set(
      caze.cases(
        pageColumn: () => const PageColumn(),
        linkColumn: () => const LinkColumn(),
        selectColumn: () => const SelectColumn(),
        multiselectColumn: () => const MultiselectColumn(),
        dateColumn: () => const DateColumn(),
        booleanColumn: () => const BooleanColumn(),
        numColumn: () => const NumColumn(),
        stringColumn: () => const StringColumn(),
      ),
    );
  }
}

@ReifiedLens(cases: [
  StringColumn,
  BooleanColumn,
  NumColumn,
  DateColumn,
  SelectColumn,
  MultiselectColumn,
  LinkColumn,
  PageColumn,
])
abstract class ColumnRows {
  const ColumnRows();
}

@immutable
@reify
class BooleanColumn extends ColumnRows with _BooleanColumnMixin {
  @override
  final Dict<RowID, bool> values;

  const BooleanColumn({this.values = const Dict()});
}

@immutable
@reify
class StringColumn extends ColumnRows with _StringColumnMixin {
  @override
  final Dict<RowID, String> values;

  const StringColumn({this.values = const Dict()});

  @override
  String toString() {
    return 'StringColumn($values)';
  }
}

@immutable
@reify
class NumColumn extends ColumnRows with _NumColumnMixin {
  @override
  final Dict<RowID, num> values;

  const NumColumn({this.values = const Dict()});
}

@immutable
@reify
class DateColumn extends ColumnRows with _DateColumnMixin {
  @override
  final Dict<RowID, DateTime> values;

  const DateColumn({this.values = const Dict()});
}

@immutable
@reify
class SelectColumn extends ColumnRows with _SelectColumnMixin {
  @override
  final Dict<TagID, Tag> tags;
  @override
  final Dict<RowID, TagID> values;

  const SelectColumn({
    this.tags = const Dict(),
    this.values = const Dict(),
  });
}

extension SelectColumnMutations on Cursor<SelectColumn> {
  TagID addTag(Tag tag) {
    tags[tag.id] = Optional(tag);
    return tag.id;
  }
}

extension MultiselectColumnMutations on Cursor<MultiselectColumn> {
  TagID addTag(Tag tag) {
    tags[tag.id] = Optional(tag);
    return tag.id;
  }
}

@immutable
@reify
class Tag with _TagMixin {
  @override
  final TagID id;
  @override
  final String name;
  @override
  final flutter.Color color;

  Tag({TagID? id, required this.name, required this.color}) : this.id = id ?? TagID();
}

@immutable
@reify
class MultiselectColumn extends ColumnRows with _MultiselectColumnMixin {
  @override
  final Dict<TagID, Tag> tags;
  @override
  final Dict<RowID, CSet<TagID>> values;

  const MultiselectColumn({
    this.tags = const Dict(),
    this.values = const Dict(),
  });
}

@immutable
@reify
class LinkColumn extends ColumnRows with _LinkColumnMixin {
  @override
  final NodeID<Table>? table;
  @override
  final Dict<RowID, RowID> values;

  const LinkColumn({
    this.values = const Dict(),
    this.table,
  });
}

@immutable
@reify
class PageColumn extends ColumnRows with _PageColumnMixin {
  @override
  final Dict<RowID, NodeID<Page>> values;

  const PageColumn({this.values = const Dict()});
}

@immutable
class _TableDataSource extends DataSource {
  final Cursor<Table> table;

  _TableDataSource(this.table);

  @override
  late final GetCursor<Vec<Datum>> data = GetCursor.compute((reader) {
    final columns = table.columnIDs.read(reader);
    return Vec([for (final column in columns) _TableDatum(table.id.read(reader), column)]);
  });
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
  final NodeID<Table> tableID;
  @override
  final ColumnID columnID;

  _TableDatum(this.tableID, this.columnID);

  @override
  Cursor<Object>? build(Reader reader, Ctx ctx) {
    final rowCtx = ctx.get<_RowCtx>();
    if (rowCtx == null) return null;
    final rowID = rowCtx.rowID;
    final table = ctx.state.getNode(tableID);
    final column = table.columns[columnID].whenPresent;
    return column.rows.cases(
      reader,
      booleanColumn: (column) => column.values[rowID],
      dateColumn: (column) => column.values[rowID],
      linkColumn: (column) => column.values[rowID],
      multiselectColumn: (column) => column.values[rowID],
      numColumn: (column) => column.values[rowID],
      pageColumn: (column) => column.values[rowID],
      selectColumn: (column) => column.values[rowID],
      stringColumn: (column) => column.values[rowID].orElse(''),
    );
  }

  @override
  GetCursor<String> name(Reader reader, Ctx ctx) {
    final table = ctx.state.getNode(tableID);
    return table.columns[columnID].whenPresent.title;
  }
}
