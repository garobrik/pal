import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;

part 'header.g.dart';

@reader_widget
Widget _tableHeader(
  BuildContext context,
  Reader reader,
  Cursor<model.Table> table,
) {
  final openColumns = useCursor(Dict<model.ColumnID, bool>());

  return Row(
    children: [
      ReorderResizeable(
        direction: Axis.horizontal,
        onReorder: (old, nu) {
          table.columnIDs.atomically((columnIDs) {
            columnIDs.insert(nu < old ? nu : nu + 1, columnIDs[old].read(null));
            columnIDs.remove(nu < old ? old + 1 : old);
          });
        },
        mainAxisSizes: [
          for (final columnID in table.columnIDs.read(reader))
            table.columns[columnID].whenPresent.width
        ],
        children: [
          for (final columnID in table.columnIDs.read(reader))
            Container(
              key: ValueKey(columnID),
              width: table.columns[columnID].whenPresent.width.read(reader),
              child: TableHeaderDropdown(
                table: table,
                column: table.columns[columnID].whenPresent,
                isOpen: openColumns[columnID].orElse(false),
              ),
            ),
        ],
      ),
      NewColumnButton(
        table: table,
        openColumns: openColumns,
        key: UniqueKey(),
      ),
    ],
  );
}

@reader_widget
Widget _tableHeaderDropdown(
  BuildContext context,
  Reader reader, {
  required Cursor<model.Table> table,
  required Cursor<model.Column> column,
  required Cursor<bool> isOpen,
}) {
  final textStyle = Theme.of(context).textTheme.bodyText1;
  final padding = EdgeInsetsDirectional.only(top: 10, bottom: 10, start: 5);

  return ReplacerDropdown(
    isOpen: isOpen,
    dropdownBuilder: (context, constraints) => IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide())),
            child: Container(
              constraints: BoxConstraints(
                minWidth: constraints.width,
                maxWidth: math.max(200, constraints.width),
                minHeight: constraints.height,
                maxHeight: constraints.height,
              ),
              child: BoundTextFormField(
                column.title,
                autofocus: true,
                style: textStyle,
                decoration: InputDecoration(
                  focusedBorder: InputBorder.none,
                  contentPadding: padding,
                ),
              ),
            ),
          ),
          ColumnConfigurationDropdown(table: table, column: column),
        ],
      ),
    ),
    child: TextButton(
      style: ButtonStyle(
        padding: MaterialStateProperty.all(padding),
        alignment: Alignment.centerLeft,
      ),
      onPressed: () {
        isOpen.mut((b) => !b);
      },
      child: Text(
        column.title.read(reader),
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

@reader_widget
Widget _columnConfigurationDropdown(
  BuildContext context,
  Reader reader, {
  required Cursor<model.Table> table,
  required Cursor<model.Column> column,
}) {
  final columnTypeIsOpen = useCursor(false);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Dropdown(
        isOpen: columnTypeIsOpen,
        childAnchor: Alignment.topRight,
        dropdownAnchor: Alignment.topLeft,
        dropdown: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final caze in model.ColumnRowsCase.values)
                TextButton(
                  autofocus: caze == column.rows.caze.read(reader),
                  onPressed: () => column.setType(caze),
                  child: Row(children: [Text('${caze.type}')]),
                ),
            ],
          ),
        ),
        child: TextButton(
          onPressed: () => columnTypeIsOpen.mut((b) => !b),
          child: Row(
            children: [Icon(Icons.list), Text('Column type')],
          ),
        ),
      ),
      ...columnSpecificConfiguration(reader, context, column),
      if (column.id.read(reader) != table.titleColumn.read(reader))
        TextButton(
          onPressed: () {
            table.columns.remove(column.id.read(null));
            table.columnIDs.remove(
              table.columnIDs
                  .read(null)
                  .indexWhere((id) => id == column.id.read(null))!,
            );
          },
          child: Row(
            children: [Icon(Icons.delete), Text('Delete column')],
          ),
        ),
    ],
  );
}

Iterable<Widget> columnSpecificConfiguration(
  Reader reader,
  BuildContext context,
  Cursor<model.Column> column,
) {
  return column.rows.cases(
    reader,
    stringColumn: (_) => [],
    booleanColumn: (_) => [],
    numColumn: (_) => [],
    dateColumn: (_) => [],
    selectColumn: (_) => [],
    multiselectColumn: (_) => [],
    linkColumn: (linkColumn) {
      final state = CursorProvider.of<model.State>(context);
      final tableID = linkColumn.table.read(reader);
      final table = tableID == null ? null : state.getNode(tableID);
      final tables = state.nodes.keys
          .read(reader)
          .whereType<model.NodeID<model.Table>>()
          .map((id) => state.getNode(id));

      return [
        ReaderWidget(builder: (_, reader) {
          final isOpen = useCursor(false);

          return Dropdown(
            isOpen: isOpen,
            dropdown: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final table in tables)
                  TextButton(
                    onPressed: () {
                      linkColumn.values.set(Dict());
                      linkColumn.table.set(table.id.read(null));
                    },
                    child: Text(table.title.read(reader)),
                  )
              ],
            ),
            child: TextButton(
              onPressed: () => isOpen.set(true),
              child: Text(
                  table == null ? 'Select table' : table.title.read(reader)),
            ),
          );
        }),
      ];
    },
  );
}

@reader_widget
Widget _newColumnButton({
  Cursor<model.Table>? table,
  Cursor<Dict<model.ColumnID, bool>>? openColumns,
}) {
  return ElevatedButton(
    onPressed: () {
      final columnID = table?.addColumn();
      if (columnID != null) {
        openColumns?[columnID] = Optional(true);
      }
    },
    child: Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.add), Text('New column')],
      ),
    ),
  );
}
