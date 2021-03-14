import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';

part 'table.g.dart';

const DEFAULT_COLUMN_WIDTH = 100.0;

@reify
class Table {
  final String title;
  final Vec<Column<Object>> columns;

  Table({this.columns = const Vec(), this.title = ''})
      : assert(columns.every((column) => column.length == columns[0].length));

  Table.from({Iterable<Column<Object>> columns = const [], this.title = ''})
      : columns = Vec.from(columns),
        assert(columns.every((col) => col.length == columns.first.length));
}

extension TableComputations on GetCursor<Table> {
  GetCursor<int> get length => columns.length.get == 0 ? Cursor.from(0) : columns[0].length;
}

extension TableMutations on Cursor<Table> {
  void addRow([int? index]) {
    columns.atomically((columns) {
      for (final column in columns.values) {
        column.values.insert(index ?? length.get, column.defaultValue.get);
      }
    });
  }

  void removeColumn(int index) {
    columns.remove(index);
  }

  void setColumnType(int index, ColumnCase columnType) {
    final column = columnType.cases<Column<Object>>(
      stringColumn: () => StringColumn(
        values: Vec(List.generate(length.get, (_) => ' ')),
        title: columns[index].title.get,
        width: columns[index].width.get,
      ),
      booleanColumn: () => BooleanColumn(
        values: Vec(List.generate(length.get, (_) => false)),
        title: columns[index].title.get,
        width: columns[index].width.get,
      ),
      intColumn: () => IntColumn(
        values: Vec(List.generate(length.get, (_) => 0)),
        title: columns[index].title.get,
        width: columns[index].width.get,
      ),
      dateColumn: () => DateColumn(
        values: Vec(List.generate(length.get, (_) => DateTime.now())),
        title: columns[index].title.get,
        width: columns[index].width.get,
      ),
    );
    columns[index].set(column);
  }
}

@ReifiedLens(cases: [StringColumn, BooleanColumn, IntColumn, DateColumn])
abstract class Column<Value> extends Iterable<Value> {
  final Vec<Value> values;
  final double width;
  final String title;

  @reify
  Value get defaultValue;

  @override
  Iterator<Value> get iterator => values.iterator;

  const Column({
    required this.values,
    required this.width,
    required this.title,
  });
}

extension ColumnLengthExtension<Value> on GetCursor<Column<Value>> {
  GetCursor<int> get length => values.length;
}

@reify
class BooleanColumn extends Column<bool> {
  const BooleanColumn({
    Vec<bool> values = const Vec(),
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(title: title, values: values, width: width);

  @override
  bool get defaultValue => false;
}

@reify
class StringColumn extends Column<String> {
  static StringColumn empty({int length = 0}) =>
      StringColumn(values: Vec(List.generate(length, (_) => '')));

  const StringColumn({
    Vec<String> values = const Vec(),
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(values: values, width: width, title: title);

  @override
  String get defaultValue => '';
}

@reify
class IntColumn extends Column<int> {
  const IntColumn({
    Vec<int> values = const Vec(),
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(title: title, values: values, width: width);

  @override
  int get defaultValue => 0;
}

@reify
class DateColumn extends Column<DateTime> {
  const DateColumn({
    Vec<DateTime> values = const Vec(),
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(title: title, values: values, width: width);

  @override
  DateTime get defaultValue => DateTime.now();
}
