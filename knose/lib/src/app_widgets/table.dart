import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/infra_widgets.dart';
import 'package:knose/app_widgets.dart';
import 'package:reorderables/reorderables.dart';

part 'table.g.dart';

@immutable
@reify
class TableBuilder with model.TypedNodeBuilder<model.Table> {
  const TableBuilder();

  @override
  model.NodeBuilderFn<model.Table> get buildTyped => MainTableWidget.tearoff;
}

@reader_widget
Widget _mainTableWidget(Reader reader, Cursor<model.State> state, Cursor<model.Table> table) {
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
                decoration: BoxDecoration(
                  color: Colors.black,
                  boxShadow: [BoxShadow(blurRadius: 4)],
                ),
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
                  onChanged: (newValue) => column.values[rowID] = newValue! ? const Optional(true) : const Optional.none(),
                  value: column.values[rowID].orElse(false).read(reader),
                ),
                multiselectColumn: (column) => Container(),
                linkColumn: (column) => Container(),
                dateColumn: (column) => Container(),
                selectColumn: (column) => Container(),
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

@reader_widget
Widget _stringField(
  BuildContext context,
  Reader reader, {
  required Cursor<Optional<String>> string,
}) {
  return TableCellTextField(
    value: string,
    toText: (Optional<String> value) => value.orElse(''),
    parse: (text) => Optional(text),
    expands: true,
  );
}

@reader_widget
Widget _numField(
  BuildContext context,
  Reader reader, {
  required Cursor<Optional<num>> number,
}) {
  return TableCellTextField(
    value: number,
    toText: (Optional<num> value) => value.unwrap?.toString() ?? '',
    parse: (text) => Optional.fromNullable(num.tryParse(text)),
    expands: false,
  );
}

@reader_widget
Widget _tableCellTextField<T>(
  BuildContext context,
  Reader reader, {
  required Cursor<Optional<T>> value,
  required String Function(Optional<T>) toText,
  required Optional<T> Function(String) parse,
  required bool expands,
}) {
  final isOpen = useCursor(false);
  final textStyle = Theme.of(context).textTheme.bodyText2;
  final padding = EdgeInsetsDirectional.only(top: 10, bottom: 5, start: 5, end: 0);
  final padding2 = EdgeInsetsDirectional.only(
      top: padding.top - 5 + 1, bottom: padding.bottom + 1, start: padding.start + 1, end: 0);
  final maxWidth = 200.0;
  final dropdownFocus = useFocusNode();

  return ReplacerWidget(
    isOpen: isOpen,
    dropdownFocus: dropdownFocus,
    offset: Offset(-1, -1),
    dropdownBuilder: (context, replacedSize) {
      final actualSize = Size(replacedSize.width + 2, replacedSize.height + 2);
      return ScrollConfiguration(
        behavior: ScrollBehavior().copyWith(scrollbars: false),
        child: ModifiedIntrinsicWidth(
          modification: expands ? 2 : 0,
          child: Container(
            constraints: expands
                ? BoxConstraints(
                    minWidth: actualSize.width - 2,
                    maxWidth: math.max(actualSize.width - 2, maxWidth),
                    minHeight: actualSize.height,
                    maxHeight: actualSize.height,
                  )
                : BoxConstraints.tight(actualSize),
            decoration: BoxDecoration(color: Theme.of(context).backgroundColor),
            alignment: AlignmentDirectional.topStart,
            child: TextFormField(
              initialValue: toText(value.read(null)),
              style: textStyle,
              focusNode: dropdownFocus,
              maxLines: expands ? null : 1,
              expands: expands,
              decoration: InputDecoration(
                focusedBorder: InputBorder.none,
                contentPadding: padding2,
              ),
              onChanged: (newText) {
                if (newText.isEmpty) value.set(Optional.none());
                parse(newText).ifPresent<T>((t) => value.set(Optional(t)));
              },
            ),
          ),
        ),
      );
    },
    child: TextButton(
      style: ButtonStyle(
        padding: MaterialStateProperty.all(padding),
      ),
      onPressed: () => isOpen.set(true),
      child: Container(
        alignment: Alignment.topLeft,
        child: Text(
          toText(value.read(reader)),
          style: textStyle,
          maxLines: expands ? 5 : 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}
