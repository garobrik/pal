import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import '../model/table.dart' as model;
import 'primitives.dart';
import 'package:flutter/material.dart';

part 'table_header.g.dart';

@reader_widget
Widget _tableHeader(Reader reader, BuildContext context, Cursor<model.Table> table) {
  return FocusTraversalGroup(
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide()),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            child: BoundTextField(
              table.title,
              style: Theme.of(context).textTheme.headline3,
              decoration: _tableCellBoundTextDecoration,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                // onReorder: (oldIdx, newIdx) {
                //   table.columns.insert(newIdx, table.columns[oldIdx].get);
                //   table.columns.remove(newIdx < oldIdx ? oldIdx + 1 : oldIdx);
                // },
                children: [
                  for (final columnID in table.columnIDs.values(reader))
                    TableHeaderCell(
                      key: ValueKey(columnID.read(reader)),
                      table: table,
                      column: table.columns[columnID.read(reader)].nonnull,
                    ),
                ],
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => table.addColumn(),
                  child: Container(
                    padding: EdgeInsets.only(right: 2),
                    child: Row(children: [Icon(Icons.add), Text('New column')]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MaterialStateEdgeInsetsGeometry extends MaterialStateProperty<EdgeInsetsGeometry?> {
  final EdgeInsetsGeometry? geometry;

  _MaterialStateEdgeInsetsGeometry(this.geometry);

  @override
  EdgeInsetsGeometry? resolve(Set<MaterialState> states) => geometry;
}

@reader_widget
Widget _tableHeaderCell(
  BuildContext context, Reader reader, {
  required Cursor<model.Table> table,
  required Cursor<model.Column> column,
}) {
  return Dropdown(
    style: ButtonStyle(
      alignment: Alignment.bottomLeft,
      padding: _MaterialStateEdgeInsetsGeometry(EdgeInsets.zero),
    ),
    childAnchor: Alignment.topCenter,
    dropdownAnchor: Alignment.topCenter,
    dropdown: ColumnConfigurationDropdown(
      column: column,
      table: table,
    ),
    child: Container(
      constraints: BoxConstraints.tightFor(
        width: column.width.read(reader),
      ),
      decoration: BoxDecoration(
        border: Border(
          right: const BorderSide(),
        ),
      ),
      padding: EdgeInsets.all(2),
      child: Text(column.title.read(reader)),
    ),
  );
}

@reader_widget
Widget _columnConfigurationDropdown(
  BuildContext context, Reader reader, {
  required Cursor<model.Column> column,
  required Cursor<model.Table> table,
}) {
  return TextButtonTheme(
    data: TextButtonThemeData(
      style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 10),
          minimumSize: Size(double.infinity, 0),
          textStyle: Theme.of(context).textTheme.bodyText1),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.all(10),
          child: BoundTextField(
            column.title,
            decoration: _tableCellBoundTextDecoration.copyWith(
              filled: true,
              fillColor: Colors.grey.shade200,
              contentPadding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Dropdown(
          childAnchor: Alignment.topRight,
          dropdownAnchor: Alignment.topLeft,
          dropdown: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final caze in model.ColumnRowsCase.values)
                TextButton(
                  onPressed: () => column.rows.set(
                    caze.cases(
                      booleanColumn: () => model.BooleanColumn(),
                      intColumn: () => model.IntColumn(),
                      stringColumn: () => model.StringColumn(),
                      dateColumn: () => model.DateColumn(),
                      selectColumn: () => model.SelectColumn(),
                      linkColumn: () => model.LinkColumn(),
                    ),
                  ),
                  child: Text(caze.type.toString()),
                ),
            ],
          ),
          child: Text(column.rows.caze.read(reader).type.toString()),
        ),
        ...columnSpecificConfigurations(reader, column),
        TextButton(
          onPressed: () {
            table.removeColumn(column.id.read(reader));
          },
          child: Text('Delete column'),
        ),
      ],
    ),
  );
}

Iterable<Widget> columnSpecificConfigurations(Reader reader, Cursor<model.Column> column) {
  return column.rows.cases(
    reader,
    booleanColumn: (_) => [],
    stringColumn: (_) => [],
    intColumn: (_) => [],
    selectColumn: (_) => [],
    dateColumn: (_) => [],
    linkColumn: (column) => [
      InheritCursor<model.State>(
        builder: (_, reader, state) => Dropdown(
          childAnchor: Alignment.topRight,
          dropdownAnchor: Alignment.topLeft,
          dropdown: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final id in state.tableIDs.read(reader))
                TextButton(
                  onPressed: () => column.table.set(id),
                  child: Text(state.tables[id].nonnull.title.read(reader)),
                ),
            ],
          ),
          child: Text(
              column.table.read(reader) == null ? '' : state.tables[column.table.read(reader)!].nonnull.title.read(reader)),
        ),
      ),
      if (column.table.read(reader) != null)
        InheritCursor<model.State>(
          builder: (_, reader, state) {
            final linkedTable = state.tables[column.table.read(reader)!].nonnull;
            final linkedColumn =
                column.column.read(reader) == null ? null : linkedTable.columns[column.column.read(reader)!].nonnull;
            return Dropdown(
              childAnchor: Alignment.topRight,
              dropdownAnchor: Alignment.topLeft,
              dropdown: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final id in linkedTable.columnIDs.read(reader))
                    TextButton(
                      onPressed: () => column.column.set(id),
                      child: Text(linkedTable.columns[id].nonnull.title.read(reader)),
                    ),
                ],
              ),
              child: Text(linkedColumn?.title.read(reader) ?? ''),
            );
          },
        ),
    ],
  );
}

const _tableCellBoundTextDecoration = InputDecoration(border: InputBorder.none, isDense: true);
