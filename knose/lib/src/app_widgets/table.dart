import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/infra_widgets.dart';
import 'package:reorderables/reorderables.dart';

part 'table.g.dart';

@reader_widget
Widget _mainTableWidget(Cursor<model.Table> table) {
  return Scrollable2D(
    child: Container(
      padding: EdgeInsets.all(20),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TableHeader(table),
            ClipRectNotBottom(
              child: Container(
                decoration: BoxDecoration(color: Colors.black, boxShadow: [BoxShadow(blurRadius: 4)]),
                constraints: BoxConstraints.expand(height: 1),
              ),
            ),
            TableRows(table),
            ElevatedButton(
              onPressed: () => table.addRow(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [Icon(Icons.add), Text('New row')],
              ),
            )
          ],
        ),
      ),
    ),
  );
}

@reader_widget
Widget _tableHeader(BuildContext context, Reader reader, Cursor<model.Table> table) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final columnID in table.columnIDs.read(reader))
        Container(
          decoration: BoxDecoration(border: Border(right: BorderSide())),
          width: table.columns[columnID].nonnull.width.read(reader),
          child: Dropdown(
            minWidth: table.columns[columnID].nonnull.width.read(reader),
            childAnchor: Alignment.topLeft,
            dropdownBuilder: (focusNode) => TableHeaderDropdown(
              focusNode: focusNode,
              column: table.columns[columnID].nonnull,
            ),
            childBuilder: (onPressed) => HookBuilder(
              builder: (_) {
                final focusNode = useFocusNode();

                return TextButton(
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.only(left: 18)),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () {
                    onPressed();
                    focusNode.skipTraversal = !focusNode.skipTraversal;
                  },
                  child: Text(
                    table.columns[columnID].nonnull.title.read(reader),
                    style: Theme.of(context).textTheme.bodyText2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
      NewColumnButton(table),
    ],
  );
}

@reader_widget
Widget _tableHeaderDropdown(
  BuildContext context,
  Reader reader, {
  FocusNode? focusNode,
  required Cursor<model.Column> column,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BoundTextFormField(
        column.title,
        focusNode: focusNode,
        autofocus: true,
        style: Theme.of(context).textTheme.bodyText2,
        decoration: InputDecoration(
          focusedBorder: InputBorder.none,
        ),
      ),
    ],
  );
}

@reader_widget
Widget _tableRows(Reader reader, Cursor<model.Table> table) {
  return ReorderableColumn(
    onReorder: (old, nu) {
      table.rowIDs.insert(nu < old ? nu : nu + 1, table.rowIDs[old].read(reader));
      table.rowIDs.remove(nu < old ? old + 1 : old);
    },
    children: [
      for (final rowID in table.rowIDs.read(reader)) TableRow(table, rowID, key: ValueKey(rowID)),
    ],
  );
}

@reader_widget
Widget _tableRow(Reader reader, Cursor<model.Table> table, model.RowID rowID) {
  return Container(
    decoration: BoxDecoration(border: Border(bottom: BorderSide())),
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (final columnID in table.columnIDs.read(reader))
            Container(
              width: table.columns[columnID].nonnull.width.read(reader),
              decoration: BoxDecoration(border: Border(right: BorderSide())),
              child: Column(
                children: [
                  table.columns[columnID].nonnull.rows.cases(
                    reader,
                    stringColumn: (Cursor<model.StringColumn> column) => BoundTextFormField(
                      column.values[rowID].orElse(''),
                      decoration: InputDecoration(
                        filled: false,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                    booleanColumn: (Cursor<model.BooleanColumn> column) => Checkbox(
                      onChanged: (newValue) => column.values[rowID].set(newValue!),
                      value: column.values[rowID].orElse(false).read(reader),
                    ),
                    multiselectColumn: (Cursor<model.MultiselectColumn> column) => Container(),
                    linkColumn: (Cursor<model.LinkColumn> column) => Container(),
                    dateColumn: (Cursor<model.DateColumn> column) => Container(),
                    intColumn: (Cursor<model.IntColumn> column) => Container(),
                    selectColumn: (Cursor<model.SelectColumn> column) => Container(),
                  )
                ],
              ),
            ),
          FocusTraversalGroup(
            descendantsAreFocusable: false,
            child: const Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: NewColumnButton(null),
            ),
          ),
        ],
      ),
    ),
  );
}

@reader_widget
Widget _newColumnButton(Cursor<model.Table>? table) {
  return ElevatedButton(
    onPressed: () => table?.addColumn(),
    child: Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.add), Text('New column')],
      ),
    ),
  );
}
