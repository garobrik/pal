import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';

import 'id.dart';

part 'table.g.dart';

const DEFAULT_COLUMN_WIDTH = 100.0;

@immutable
@reify
class State with _StateMixin {
  final Dict<TableID, Table> tables;
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
  final TableID id;
  final String title;
  final Dict<ColumnID, Column<Object>> columns;
  final Vec<ColumnID> columnIDs;
  final Vec<RowID> rowIDs;

  Table({
    TableID? id,
    Dict<ColumnID, Column<Object>>? columns,
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
  void addRow([int? index]) {
    final rowID = RowID();
    for (final columnID in columnIDs.values) {
      final column = columns[columnID.get];
      column.values[rowID] = column.defaultValue.get;
    }
    rowIDs.insert(index ?? rowIDs.length.get, rowID);
  }

  void addColumn([int? index]) {
    atomically((table) {
      final columnID = ColumnID();

      final column = StringColumn(
        id: columnID,
        values: Dict({
          for (final key in table.rowIDs.values) key.get: '',
        }),
      );

      table.columns[columnID] = column;
      table.columnIDs.insert(index ?? table.columnIDs.length.get, columnID);
    });
  }

  void removeColumn(ColumnID id) {
    columns.remove(id);
    for (final indexedValue in columnIDs.indexedValues) {
      if (indexedValue.value.get == id) {
        columnIDs.remove(indexedValue.index);
        return;
      }
    }
  }
}

@immutable
@ReifiedLens(cases: [StringColumn, BooleanColumn, IntColumn, DateColumn, SelectColumn, LinkColumn])
abstract class Column<Value> {
  final ColumnID id;
  final Dict<RowID, Value> values;
  final double width;
  final String title;

  @reify
  Value get defaultValue;

  const Column({
    required this.id,
    required this.values,
    required this.width,
    required this.title,
  });
}

extension ColumnMutations on Cursor<Column<Object>> {
  void setType(ColumnCase columnType) {
    set(
      columnType.cases<Column<Object>>(
        stringColumn: () => StringColumn(
          values: Dict({for (final key in values.keys.get) key: ''}),
          title: title.get,
          width: width.get,
        ),
        booleanColumn: () => BooleanColumn(
          values: Dict({for (final key in values.keys.get) key: false}),
          title: title.get,
          width: width.get,
        ),
        intColumn: () => IntColumn(
          values: Dict({for (final key in values.keys.get) key: 0}),
          title: title.get,
          width: width.get,
        ),
        dateColumn: () => DateColumn(
          values: Dict({for (final key in values.keys.get) key: DateTime.now()}),
          title: title.get,
          width: width.get,
        ),
        selectColumn: () => SelectColumn(
          values: Dict({for (final key in values.keys.get) key: const Optional.none()}),
          title: title.get,
          width: width.get,
        ),
        linkColumn: () => LinkColumn(
          values: Dict({for (final key in values.keys.get) key: const Optional.none()}),
          title: title.get,
          width: width.get,
        ),
      ),
    );
  }
}

@immutable
@reify
class BooleanColumn extends Column<bool> with _BooleanColumnMixin {
  BooleanColumn({
    ColumnID? id,
    Dict<RowID, bool>? values,
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(id: id ?? ColumnID(), title: title, values: values ?? Dict(), width: width);

  @override
  bool get defaultValue => false;
}

@immutable
@reify
class StringColumn extends Column<String> with _StringColumnMixin {
  StringColumn({
    ColumnID? id,
    Dict<RowID, String>? values,
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(id: id ?? ColumnID(), values: values ?? Dict(), width: width, title: title);

  @override
  String get defaultValue => '';
}

@immutable
@reify
class IntColumn extends Column<int> with _IntColumnMixin {
  IntColumn({
    ColumnID? id,
    Dict<RowID, int>? values,
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(id: id ?? ColumnID(), title: title, values: values ?? Dict(), width: width);

  @override
  int get defaultValue => 0;
}

@immutable
@reify
class DateColumn extends Column<DateTime> with _DateColumnMixin {
  DateColumn({
    ColumnID? id,
    Dict<RowID, DateTime>? values,
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(id: id ?? ColumnID(), title: title, values: values ?? Dict(), width: width);

  @override
  DateTime get defaultValue => DateTime.now();
}

@immutable
@reify
class SelectColumn extends Column<Optional<String>> with _SelectColumnMixin {
  final CSet<String> possibleValues;

  SelectColumn({
    ColumnID? id,
    Dict<RowID, Optional<String>>? values,
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
    CSet<String>? possibleValues,
  })  : possibleValues = possibleValues ?? CSet(),
        super(id: id ?? ColumnID(), title: title, values: values ?? Dict(), width: width);

  @override
  Optional<String> get defaultValue => const Optional.none();
}

@immutable
@reify
class LinkColumn extends Column<Optional<RowID>> with _LinkColumnMixin {
  final TableID? table;
  final ColumnID? column;

  LinkColumn({
    ColumnID? id,
    Dict<RowID, Optional<RowID>>? values,
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
    this.table,
    this.column,
  }) : super(id: id ?? ColumnID(), title: title, values: values ?? Dict(), width: width);

  @override
  Optional<RowID> get defaultValue => const Optional.none();
}
