import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:functional/functional.dart';

part 'table.g.dart';

const DEFAULT_COLUMN_WIDTH = 100;

@reified_lens
class Table {
  final Vec<Column> columns;

  const Table({this.columns = const Vec.empty()});
  const Table.empty() : columns = const Vec.empty();
  Table.from({Iterable<Column> columns = const []})
      : columns = Vec.from(columns);

  int get length => columns.isEmpty ? 0 : columns.first.length;
}

@reified_lens
abstract class Column<Value> {
  Vec<Value> get values;
  Column<Value> mut_values(Vec<Value> values);
  int get length => values.length;
  int get width;
  Column<Value> mut_width(int width);

  const Column();
}

@reified_lens
class StringColumn extends Column<String> {
  @override
  final Vec<String> values;
  @override
  final int width;

  const StringColumn({this.values = const Vec.empty(), this.width = DEFAULT_COLUMN_WIDTH});
  StringColumn.from({Iterable<String> values = const [], this.width = DEFAULT_COLUMN_WIDTH})
      : values = Vec.from(values);

  @override
  Column<String> mut_values(Vec<String> values) => copyWith(values: values);
  @override
  Column<String> mut_width(int width) => copyWith(width: width);
}
