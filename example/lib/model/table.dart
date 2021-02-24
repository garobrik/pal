import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'table.g.dart';

const DEFAULT_COLUMN_WIDTH = 100.0;

@reify
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
}

extension TableComputations on GetCursor<Table> {
  GetCursor<int> get length =>
      columns.length.get == 0 ? Cursor.from(0) : columns[0].length;
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
    final column = (columnType == StringColumn
        ? StringColumn.from(
            values: List.generate(length.get, (_) => ' '),
            title: columns[index].title.get,
            width: columns[index].width.get,
          )
        : BooleanColumn.from(
            values: List.generate(length.get, (_) => false),
            title: columns[index].title.get,
            width: columns[index].width.get,
          )) as Column<Object>;
    columns[index].set(column);
  }
}

@reify
abstract class Column<Value> extends Iterable<Value> {
  @reify
  Vec<Value> get values;
  Column<Value> mut_values(Vec<Value> values);
  @reify
  double get width;
  Column<Value> mut_width(double width);
  @reify
  String get title;
  Column<Value> mut_title(String title);

  @reify
  Value get defaultValue;

  T cases<T>({
    required T Function(StringColumn) string,
    required T Function(BooleanColumn) boolean,
  });

  @override
  Iterator<Value> get iterator => values.iterator;

  const Column();
}

extension ColumnLengthExtension<Value> on GetCursor<Column<Value>> {
  GetCursor<int> get length => values.length;
}

extension ColumnCursorCasesExtension<Value> on Cursor<Column<Value>> {
  T cases<T>(
      {required T Function(Cursor<StringColumn>) string,
      required T Function(Cursor<BooleanColumn>) boolean}) {
    switch (type.get) {
      case StringColumn:
        return string(this.cast<StringColumn>());
      case BooleanColumn:
        return boolean(this.cast<BooleanColumn>());
      default:
        // TODO: make proper unreachable exception
        throw Exception();
    }
  }

  GetCursor<Type> get type => thenGet<Type>(
        Getter.field(
          'case',
          (column) => column.cases(
              string: (_) => StringColumn, boolean: (_) => BooleanColumn),
        ),
      );
}

@reify
class BooleanColumn extends Column<bool> {
  @override
  final Vec<bool> values;
  @override
  final double width;
  @override
  final String title;

  BooleanColumn.empty({
    int length = 0,
    this.title = '',
    this.width = DEFAULT_COLUMN_WIDTH,
  }) : values = Vec.from(Iterable.generate(length, (_) => false));

  const BooleanColumn({
    this.values = const Vec.empty(),
    this.width = DEFAULT_COLUMN_WIDTH,
    required this.title,
  });

  BooleanColumn.from({
    Iterable<bool> values = const [],
    this.width = DEFAULT_COLUMN_WIDTH,
    required this.title,
  }) : values = Vec.from(values);

  @override
  T cases<T>({
    required T Function(StringColumn p1) string,
    required T Function(BooleanColumn p1) boolean,
  }) {
    return boolean(this);
  }

  @override
  Column<bool> mut_title(String title) => copyWith(title: title);
  @override
  Column<bool> mut_values(Vec<bool> values) => copyWith(values: values);
  @override
  Column<bool> mut_width(double width) => copyWith(width: width);

  @override
  bool get defaultValue => false;
}

@reify
class StringColumn extends Column<String> {
  @override
  final Vec<String> values;
  @override
  final double width;
  @override
  final String title;

  StringColumn.empty(
      {int length = 0, this.title = '', this.width = DEFAULT_COLUMN_WIDTH})
      : values = Vec.from(Iterable.generate(length, (_) => ''));

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
  T cases<T>(
          {required T Function(StringColumn) string,
          required T Function(BooleanColumn) boolean}) =>
      string(this);

  @override
  String get defaultValue => '';
}
