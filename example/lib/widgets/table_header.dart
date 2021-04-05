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
                  for (final indexedColumnID in table.columnIDs.indexedValues)
                    TableHeaderCell(
                      key: ValueKey(indexedColumnID.value.get),
                      table: table,
                      column: table.columns[indexedColumnID.value.get],
                      columnIndex: indexedColumnID.index,
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
  required Cursor<model.Column<Object>> column,
  required int columnIndex,
}) {
  return Dropdown(
    style: ButtonStyle(alignment: Alignment.bottomLeft),
    childAnchor: Alignment.topCenter,
    dropdownAnchor: Alignment.topCenter,
    dropdown: ColumnConfigurationDropdown(
      column: column,
      table: table,
      columnIndex: columnIndex,
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
  required Cursor<model.Column<Object>> column,
  required Cursor<model.Table> table,
  required int columnIndex,
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
              for (final caze in model.ColumnCase.values)
                TextButton(
                  onPressed: () => column.setType(caze),
                  child: Text(caze.type.toString()),
                ),
            ],
          ),
          child: Text(column.caze.get.type.toString()),
        ),
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

const _tableCellBoundTextDecoration = InputDecoration(border: InputBorder.none, isDense: true);
