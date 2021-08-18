import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:reorderables/reorderables.dart';
import 'package:knose/model.dart' as model;

part 'rows.g.dart';

@reader_widget
Widget _tableRows(Reader reader, Cursor<model.Table> table) {
  final scrollController = useScrollController();

  return ReorderableColumn(
    scrollController: scrollController,
    onReorder: (old, nu) {
      table.rowIDs.atomically((rowIDs) {
        rowIDs.insert(nu < old ? nu : nu + 1, rowIDs[old].read(null));
        rowIDs.remove(nu < old ? old + 1 : old);
      });
    },
    children: [
      for (final rowID in table.rowIDs.read(reader))
        TableRow(
          table,
          rowID,
          key: ValueKey(rowID),
        ),
    ],
  );
}

@reader_widget
Widget _tableRow(Reader reader, Cursor<model.Table> table, model.RowID rowID) {
  return Container(
    decoration: BoxDecoration(border: Border(bottom: BorderSide())),
    child: IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final columnID in table.columnIDs.read(reader))
            Container(
              key: ValueKey(columnID),
              width: table.columns[columnID].whenPresent.width.read(reader),
              decoration: BoxDecoration(border: Border(right: BorderSide())),
              child: table.columns[columnID].whenPresent.rows.cases(
                reader,
                stringColumn: (column) => StringField(string: column.values[rowID]),
                numColumn: (column) => NumField(number: column.values[rowID]),
                booleanColumn: (column) => Checkbox(
                  onChanged: (newValue) => column.values[rowID] =
                      newValue! ? const Optional(true) : const Optional.none(),
                  value: column.values[rowID].orElse(false).read(reader),
                ),
                selectColumn: (column) => SelectField(
                  column: column,
                  row: column.values[rowID],
                ),
                multiselectColumn: (column) => MultiselectField(
                  column: column,
                  row: column.values[rowID].orElse(CSet()),
                ),
                linkColumn: (column) => Container(),
                dateColumn: (column) => Container(),
              ),
            ),
          FocusTraversalGroup(
            descendantsAreFocusable: false,
            child: const Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: NewColumnButton(),
            ),
          ),
        ],
      ),
    ),
  );
}
