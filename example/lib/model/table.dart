import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

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
      columns.forEach((column) {
        column.values.insert(index ?? length.get, column.defaultValue.get);
      });
    });
  }

  void removeColumn(int index) {
    columns.remove(index);
  }

  void setColumnType(int index, Type columnType) {
    late final Column<Object> column;
    if (columnType == StringColumn) {
      column = StringColumn(
        values: Vec(List.generate(length.get, (_) => ' ')),
        title: columns[index].title.get,
        width: columns[index].width.get,
      );
    } else if (columnType == BooleanColumn) {
      column = BooleanColumn(
        values: Vec(List.generate(length.get, (_) => false)),
        title: columns[index].title.get,
        width: columns[index].width.get,
      );
    } else if (columnType == IntColumn) {
      column = IntColumn(
        values: Vec(List.generate(length.get, (_) => 0)),
        title: columns[index].title.get,
        width: columns[index].width.get,
      );
    }
    columns[index].set(column);
  }
}

@ReifiedLens(cases: [StringColumn, BooleanColumn, IntColumn])
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
