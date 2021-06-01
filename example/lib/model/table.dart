import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';

import 'id.dart';

part 'table.g.dart';

@immutable
@reify
class State with _StateMixin {
  @override
  final Dict<TableID, Table> tables;
  @override
  final Vec<TableID> tableIDs;

  State({
    Dict<TableID, Table>? tables,
    this.tableIDs = const Vec(),
  }) : tables = tables ?? Dict();
}

extension StateMutations on Cursor<State> {
  TableID addTable() {
    final newID = TableID();
    tables[newID] = Table(id: newID);
    tableIDs.add(newID);
    return newID;
  }
}

class TableID extends UUID<TableID> {}

class ColumnID extends UUID<ColumnID> {}

class RowID extends UUID<RowID> {}

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
  final Vec<RowID> rowIDs;

  Table({
    TableID? id,
    Dict<ColumnID, Column>? columns,
    this.title = '',
    this.columnIDs = const Vec(),
    this.rowIDs = const Vec(),
  })  : this.id = id ?? TableID(),
        this.columns = columns ?? Dict();
}

extension TableComputations on GetCursor<Table> {
  GetCursor<int> get length => rowIDs.length;
}

extension TableMutations on Cursor<Table> {
  void addRow([int? index]) => rowIDs.insert(index ?? rowIDs.length.read(noopReader), RowID());

  void addColumn([int? index]) {
    atomically((table) {
      final columnID = ColumnID();

      final column = Column(
        id: columnID,
        rows: StringColumn(),
      );

      table.columns[columnID] = column;
      table.columnIDs.insert(index ?? table.columnIDs.length.read(noopReader), columnID);
    });
  }

  void removeColumn(ColumnID id) {
    columns.remove(id);
    for (final indexedValue in columnIDs.indexedValues(noopReader)) {
      if (indexedValue.value.read(noopReader) == id) {
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

  const Column({
    required this.id,
    required this.rows,
    this.width = 100,
    this.title = '',
  });
}

@ReifiedLens(cases: [StringColumn, BooleanColumn, IntColumn, DateColumn, SelectColumn, LinkColumn])
abstract class ColumnRows {
  // @reify
  // Dict<RowID, Object> get values;
}

@immutable
@reify
class BooleanColumn extends ColumnRows with _BooleanColumnMixin {
  @override
  final Dict<RowID, bool> values;

  BooleanColumn({Dict<RowID, bool>? values}) : values = values ?? Dict();
}

@immutable
@reify
class StringColumn extends ColumnRows with _StringColumnMixin {
  @override
  final Dict<RowID, String> values;

  StringColumn({Dict<RowID, String>? values}) : values = values ?? Dict();
}

@immutable
@reify
class IntColumn extends ColumnRows with _IntColumnMixin {
  @override
  final Dict<RowID, int> values;

  IntColumn({Dict<RowID, int>? values}) : values = values ?? Dict();
}

@immutable
@reify
class DateColumn extends ColumnRows with _DateColumnMixin {
  @override
  final Dict<RowID, DateTime> values;

  DateColumn({Dict<RowID, DateTime>? values}) : values = values ?? Dict();
}

@immutable
@reify
class SelectColumn extends ColumnRows with _SelectColumnMixin {
  @override
  final CSet<String> possibleValues;
  @override
  final Dict<RowID, String> values;

  SelectColumn({
    CSet<String>? possibleValues,
    Dict<RowID, String>? values,
  })  : possibleValues = possibleValues ?? CSet(),
        values = values ?? Dict();
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

  LinkColumn({
    Dict<RowID, RowID>? values,
    this.table,
    this.column,
  }) : values = values ?? Dict();
}
