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
    final column = (columnType == StringColumn
        ? StringColumn(
            values: Vec(List.generate(length.get, (_) => ' ')),
            title: columns[index].title.get,
            width: columns[index].width.get,
          )
        : BooleanColumn(
            values: Vec(List.generate(length.get, (_) => false)),
            title: columns[index].title.get,
            width: columns[index].width.get,
          )) as Column<Object>;
    columns[index].set(column);
  }
}

@ReifiedLens(cases: [
  StringColumn,
  BooleanColumn,
])
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
    Vec<bool> values = const Vec.empty(),
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(title: title, values: values, width: width);

  BooleanColumn.empty({
    int length = 0,
    String title = '',
    double width = DEFAULT_COLUMN_WIDTH,
  }) : super(
          title: title,
          width: width,
          values: Vec(List.generate(length, (_) => false)),
        );

  @override
  bool get defaultValue => false;
}

@reify
class StringColumn extends Column<String> {
  StringColumn.empty({
    int length = 0,
    String title = '',
    double width = DEFAULT_COLUMN_WIDTH,
  }) : super(values: Vec(List.generate(length, (_) => '')), width: width, title: title);

  const StringColumn({
    Vec<String> values = const Vec.empty(),
    double width = DEFAULT_COLUMN_WIDTH,
    String title = '',
  }) : super(values: values, width: width, title: title);

  @override
  String get defaultValue => '';
}

extension ColumnCursorCasesExtension<Value> on Cursor<Column<Value>> {
  T cases<T>({
    required T Function(Cursor<StringColumn>) string,
    required T Function(Cursor<BooleanColumn>) boolean,
  }) {
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
          'type',
          (column) {
            if (column is StringColumn) {
              return StringColumn;
            } else if (column is BooleanColumn) {
              return BooleanColumn;
            } else {
              throw Error();
            }
          },
        ),
      );
}
