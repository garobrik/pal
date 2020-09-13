import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:functional/functional.dart';

part 'table.g.dart';

@reified_lens
class Table {
  final Vec<Column> columns;

  const Table({this.columns});
  const Table.empty() : columns = const Vec.empty();
  Table.from({Iterable<Column> columns}) : columns = Vec.from(columns);

  int get length => columns.isEmpty ? 0 : columns.first.length;
}

@reified_lens
abstract class Column<Value> {
  Vec<Value> get values;
  Column<Value> mut_values(Vec<Value> values);
  int get length => values.length;

  const Column();
}

@reified_lens
class StringColumn extends Column<String> {
  final Vec<String> values;

  const StringColumn({this.values});
  const StringColumn.empty() : values = const Vec.empty();
  StringColumn.from({Iterable<String> values}) : values = Vec.from(values);

  @override
  Column<String> mut_values(Vec<String> values) => copyWith(values: values);
}
