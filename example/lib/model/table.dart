import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'table.g.dart';

const DEFAULT_COLUMN_WIDTH = 100.0;

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
  double get width;
  Column<Value> mut_width(double width);
  String get title;
  Column<Value> mut_title(String title);

  const Column();
}

@reified_lens
class StringColumn extends Column<String> {
  @override
  final Vec<String> values;
  @override
  final double width;
  @override
  final String title;

  const StringColumn({
    this.values = const Vec.empty(),
    this.width = DEFAULT_COLUMN_WIDTH,
    required this.title,
  });

  StringColumn.from({
    Iterable<String> values = const [],
    this.width = DEFAULT_COLUMN_WIDTH,
    required this.title,
  }) : values = Vec.from(values);

  @override
  Column<String> mut_values(Vec<String> values) => copyWith(values: values);
  @override
  Column<String> mut_width(double width) => copyWith(width: width);

  @override
  Column<String> mut_title(String title) => copyWith(title: title);
}
