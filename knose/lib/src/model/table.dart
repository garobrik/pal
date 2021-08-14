import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';

import 'package:knose/model.dart' hide List;

part 'table.g.dart';

class TableID extends UUID<TableID> {}

class ColumnID extends UUID<ColumnID> {}

class RowID extends UUID<RowID> {}

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
  final Vec<RowID> rowIDs;
  @override
  final Dict<RowID, NodeID<Page>> pages;

  Table({
    NodeID<Table>? id,
    this.columns = const Dict(),
    this.title = '',
    this.columnIDs = const Vec(),
    this.rowIDs = const Vec(),
    this.pages = const Dict(),
  }) : this.id = id ?? NodeID<Table>();

  static Table newDefault() {
    final columns = [
      Column(
        id: ColumnID(),
        rows: StringColumn(),
        title: 'Task',
      ),
      Column(
        id: ColumnID(),
        rows: BooleanColumn(),
        title: 'Done',
      ),
    ];

    return Table(
      columns: Dict({for (final column in columns) column.id: column}),
      columnIDs: Vec([for (final column in columns) column.id]),
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
      final column = Column(rows: StringColumn());

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
        linkColumn: () => LinkColumn(),
        selectColumn: () => SelectColumn(),
        multiselectColumn: () => MultiselectColumn(),
        dateColumn: () => DateColumn(),
        booleanColumn: () => BooleanColumn(),
        numColumn: () => NumColumn(),
        stringColumn: () => StringColumn(),
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
  LinkColumn
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
  final CSet<String> possibleValues;
  @override
  final Dict<RowID, String> values;

  const SelectColumn({
    this.possibleValues = const CSet(),
    this.values = const Dict(),
  });
}

@immutable
@reify
class MultiselectColumn extends ColumnRows with _MultiselectColumnMixin {
  @override
  final CSet<String> possibleValues;
  @override
  final Dict<RowID, CSet<String>> values;

  const MultiselectColumn({
    this.possibleValues = const CSet(),
    this.values = const Dict(),
  });
}

@immutable
@reify
class LinkColumn extends ColumnRows with _LinkColumnMixin {
  @override
  final TableID? table;
  @override
  final ColumnID? column;
  @override
  final Dict<RowID, RowID> values;

  const LinkColumn({
    this.values = const Dict(),
    this.table,
    this.column,
  });
}
