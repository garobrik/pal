import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;

part 'table_header.g.dart';

@reader_widget
Widget _tableHeader(BuildContext context, Reader reader, Cursor<model.Table> table) {
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
          for (final columnID in table.columnIDs.read(reader)) table.columns[columnID].nonnull.width
        ],
        children: [
          for (final columnID in table.columnIDs.read(reader))
            Container(
              key: ValueKey(columnID),
              width: table.columns[columnID].nonnull.width.read(reader),
              child: TableHeaderDropdown(table: table, column: table.columns[columnID].nonnull),
            ),
        ],
      ),
      NewColumnButton(table, key: UniqueKey()),
    ],
  );
}

@reader_widget
Widget _tableHeaderDropdown(
  BuildContext context,
  Reader reader, {
  required Cursor<model.Table> table,
  required Cursor<model.Column> column,
}) {
  final isOpen = useState(false);
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
        isOpen.value = !isOpen.value;
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
  Reader reader, {
  required Cursor<model.Table> table,
  required Cursor<model.Column> column,
}) {
  final columnTypeIsOpen = useState(false);

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
              TextButton(
                autofocus: true,
                onPressed: () => column.rows.set(model.StringColumn()),
                child: Row(
                  children: [
                    Text('Text'),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => column.rows.set(model.BooleanColumn()),
                child: Row(
                  children: [
                    Text('Checkbox'),
                  ],
                ),
              ),
            ],
          ),
        ),
        child: TextButton(
          onPressed: () => columnTypeIsOpen.value = true,
          child: Row(
            children: [Icon(Icons.list), Text('Column type')],
          ),
        ),
      ),
      TextButton(
        onPressed: () {},
        child: Row(
          children: [Icon(Icons.delete), Text('Delete column')],
        ),
      ),
    ],
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
