import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'table.g.dart';

const DEFAULT_COLUMN_WIDTH = 100.0;

@reified_lens
class Table {
  final Vec<Column<Object>> columns;

  const Table.empty() : columns = const Vec.empty();
  Table({this.columns = const Vec.empty()})
      : assert(columns.every((column) => column.length == columns[0].length));
  Table.from({Iterable<Column<Object>> columns = const []})
      : columns = Vec.from(columns),
        assert(
          columns.every((column) => column.length == columns.first.length),
        );

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

  @skip_lens
  T cases<T>({required T Function(StringColumn) string});

  const Column();
}

extension ColumnCursorCasesExtension<Value> on Cursor<Column<Value>> {
  T cases<T>({required T Function(Cursor<StringColumn>) string}) {
    Type thisCase = this
        .thenGet<Type>(
          Getter.field(
            'case',
            (column) => column.cases(string: (_) => StringColumn),
          ),
        )
        .get;

    switch (thisCase) {
      case StringColumn:
        return string(this.cast<StringColumn>());
      default:
        // TODO: make proper unreachable exception
        throw Exception();
    }
  }
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

  @override
  @skip_lens
  T cases<T>({required T Function(StringColumn p1) string}) => string(this);
}
