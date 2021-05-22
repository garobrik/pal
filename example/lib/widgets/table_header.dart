import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import '../model/table.dart' as model;
import 'primitives.dart';
import 'package:flutter/material.dart';

part 'table_header.g.dart';

@bound_widget
Widget _tableHeader(BuildContext context, Cursor<model.Table> table) {
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
                  for (final columnID in table.columnIDs.values)
                    TableHeaderCell(
                      key: ValueKey(columnID.get),
                      table: table,
                      column: table.columns[columnID.get].nonnull,
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

@bound_widget
Widget _tableHeaderCell(
  BuildContext context, {
  required Cursor<model.Table> table,
  required Cursor<model.Column> column,
}) {
  return Dropdown(
    style: ButtonStyle(alignment: Alignment.bottomLeft),
    childAnchor: Alignment.topCenter,
    dropdownAnchor: Alignment.topCenter,
    dropdown: ColumnConfigurationDropdown(
      column: column,
      table: table,
    ),
    child: Container(
      constraints: BoxConstraints.tightFor(
        width: column.width.get,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: const BorderSide(),
        ),
      ),
      padding: EdgeInsets.all(2),
      child: Text(column.title.get),
    ),
  );
}

@bound_widget
Widget _columnConfigurationDropdown(
  BuildContext context, {
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
          child: Text(column.rows.caze.get.type.toString()),
        ),
        ...columnSpecificConfigurations(column),
        TextButton(
          onPressed: () {
            table.removeColumn(column.id.get);
          },
          child: Text('Delete column'),
        ),
      ],
    ),
  );
}

Iterable<Widget> columnSpecificConfigurations(Cursor<model.Column> column) {
  return column.rows.cases(
    booleanColumn: (_) => [],
    stringColumn: (_) => [],
    intColumn: (_) => [],
    selectColumn: (_) => [],
    dateColumn: (_) => [],
    linkColumn: (column) => [
      InheritCursor<model.State>(
        builder: (_, state) => Dropdown(
          childAnchor: Alignment.topRight,
          dropdownAnchor: Alignment.topLeft,
          dropdown: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final id in state.tableIDs.get)
                TextButton(
                  onPressed: () => column.table.set(id),
                  child: Text(state.tables[id].nonnull.title.get),
                ),
            ],
          ),
          child: Text(column.table.get == null ? '' : state.tables[column.table.get!].nonnull.title.get),
        ),
      ),
      if (column.table.get != null)
        InheritCursor<model.State>(
          builder: (_, state) {
            final linkedTable = state.tables[column.table.get!].nonnull;
            final linkedColumn =
                column.column.get == null ? null : linkedTable.columns[column.column.get!].nonnull;
            return Dropdown(
              childAnchor: Alignment.topRight,
              dropdownAnchor: Alignment.topLeft,
              dropdown: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final id in linkedTable.columnIDs.get)
                    TextButton(
                      onPressed: () => column.column.set(id),
                      child: Text(linkedTable.columns[id].nonnull.title.get),
                    ),
                ],
              ),
              child: Text(linkedColumn?.title.get ?? ''),
            );
          },
        ),
    ],
  );
}

const _tableCellBoundTextDecoration = InputDecoration(border: InputBorder.none, isDense: true);
