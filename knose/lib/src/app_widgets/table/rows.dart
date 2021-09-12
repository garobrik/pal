import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
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
Widget _tableRow(
  Reader reader,
  Cursor<model.Table> table,
  model.RowID rowID, {
  bool enabled = true,
  bool trailingNewColumnSpace = true,
}) {
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
                stringColumn: (column) => StringField(
                  string: column.values[rowID],
                  enabled: enabled,
                ),
                numColumn: (column) => NumField(
                  number: column.values[rowID],
                  enabled: enabled,
                ),
                booleanColumn: (column) => Checkbox(
                  onChanged: !enabled
                      ? null
                      : (newValue) => column.values[rowID] =
                          newValue! ? const Optional(true) : const Optional.none(),
                  value: column.values[rowID].orElse(false).read(reader),
                ),
                selectColumn: (column) => SelectField(
                  column: column,
                  row: column.values[rowID],
                  enabled: enabled,
                ),
                multiselectColumn: (column) => MultiselectField(
                  column: column,
                  row: column.values[rowID].orElse(CSet()),
                  enabled: enabled,
                ),
                linkColumn: (column) => LinkField(
                  column: column,
                  rowCursor: column.values[rowID],
                  enabled: enabled,
                ),
                dateColumn: (column) => Container(),
                pageColumn: (column) => Container(),
              ),
            ),
          if (trailingNewColumnSpace)
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

@reader_widget
Widget _linkField(
  Reader reader,
  BuildContext context, {
  required Cursor<model.LinkColumn> column,
  required Cursor<Optional<model.RowID>> rowCursor,
  bool enabled = true,
}) {
  final state = CursorProvider.of<model.State>(context);
  final isOpen = useCursor(false);
  final tableID = column.table.read(reader);
  final title = (Reader reader) {
    final row = rowCursor.read(reader).unwrap;
    if (row == null || tableID == null) return null;
    final table = state.getNode(tableID);
    return table.columns[table.titleColumn.read(reader)].whenPresent.rows
        .cast<model.StringColumn>()
        .values[row]
        .read(reader)
        .unwrap;
  };

  final focusForRow = useMemoized(() {
    final map = <model.RowID, FocusNode>{};
    return (model.RowID rowID) => map.putIfAbsent(rowID, () => FocusNode());
  });
  FocusNode? currentFocus;
  if (tableID != null) {
    final table = state.getNode(tableID);
    final length = table.rowIDs.length.read(reader);
    if (length > 0) {
      currentFocus = focusForRow(table.rowIDs[0].read(reader));
    }
  }

  return DeferredDropdown(
    offset: Offset(-1, -1),
    isOpen: isOpen,
    dropdownFocus: currentFocus,
    childAnchor: Alignment.topLeft,
    dropdown: ReaderWidget(
      builder: (_, reader) {
        final table = state.getNode(tableID!);
        final width = table.columns.keys
            .read(reader)
            .map(
              (colID) => table.columns[colID].whenPresent.width.read(reader),
            )
            .reduce((a, b) => a + b);

        return Container(
          constraints: BoxConstraints(maxWidth: width),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: table.rowIDs.length.read(reader),
            itemBuilder: (_, index) => ReaderWidget(
              builder: (_, reader) {
                final rowID = table.rowIDs[index].read(reader);
                return TextButton(
                  focusNode: focusForRow(rowID),
                  style: ButtonStyle(
                    alignment: Alignment.centerLeft,
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () => rowCursor.set(Optional(rowID)),
                  child: TableRow(
                    table,
                    rowID,
                    enabled: false,
                    trailingNewColumnSpace: false,
                    key: ValueKey(rowID),
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
    child: TextButton(
      style: ButtonStyle(alignment: Alignment.centerLeft),
      onPressed: (tableID == null || !enabled) ? null : () => isOpen.set(true),
      child: Text(
        title(reader) ?? '',
        style: TextStyle(decoration: TextDecoration.underline),
      ),
    ),
  );
}
