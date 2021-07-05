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
  @override
  final Dict<PageID, Page> pages;
  @override
  final Vec<PageID> pageIDs;

  State({
    this.tables = const Dict(),
    this.tableIDs = const Vec(),
    this.pages = const Dict(),
    this.pageIDs = const Vec(),
  });
}

extension StateMutations on Cursor<State> {
  TableID addTable() {
    final newID = TableID();
    tables[newID] = Table(id: newID);
    tableIDs.add(newID);
    return newID;
  }
}

@ReifiedLens(cases: [TableID, PageID])
abstract class PageOrTableID with _PageOrTableIDMixin {}

class TableID extends UUID<TableID> {}

class ColumnID extends UUID<ColumnID> {}

class RowID extends UUID<RowID> {}

class PageID extends UUID<PageID> {}

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
  @override
  final Dict<RowID, PageID> pages;

  Table({
    TableID? id,
    this.columns = const Dict(),
    this.title = '',
    this.columnIDs = const Vec(),
    this.rowIDs = const Vec(),
    this.pages = const Dict(),
  }) : this.id = id ?? TableID();
}

@immutable
@reify
class Page with _PageMixin {
  @override
  final String title;
  @override
  final String contents;
  @override
  final PageID id;

  Page({this.title = '', this.contents = '', PageID? id}) : this.id = id ?? PageID();
}

extension TableComputations on GetCursor<Table> {
  GetCursor<int> get length => rowIDs.length;
}

extension TableMutations on Cursor<Table> {
  void addRow([int? index]) => rowIDs.insert(index ?? rowIDs.length.read(null), RowID());

  void addColumn([int? index]) {
    atomically((table) {
      final columnID = ColumnID();

      final column = Column(
        id: columnID,
        rows: StringColumn(),
      );

      table.columns[columnID] = column;
      table.columnIDs.insert(index ?? table.columnIDs.length.read(null), columnID);
    });
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

  const Column({
    required this.id,
    required this.rows,
    this.width = 100,
    this.title = '',
  });
}

@ReifiedLens(cases: [
  StringColumn,
  BooleanColumn,
  IntColumn,
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
class IntColumn extends ColumnRows with _IntColumnMixin {
  @override
  final Dict<RowID, int> values;

  const IntColumn({this.values = const Dict()});
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
