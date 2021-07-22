import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/infra_widgets.dart';
import 'package:knose/app_widgets.dart';
import 'package:reorderables/reorderables.dart';

part 'table.g.dart';

Route<Null> generateTableRoute(Cursor<model.State> state, model.TableID tableID) {
  final table = state.tables[tableID].nonnull;
  return MaterialPageRoute(
    settings: RouteSettings(name: table.title.read(null), arguments: model.TableRoute(tableID)),
    builder: (_) => MainScaffold(
      title: EditableScaffoldTitle(table.title),
      state: state,
      body: MainTableWidget(table),
      replaceRouteOnPush: false,
    ),
  );
}

@reader_widget
Widget _mainTableWidget(Reader reader, Cursor<model.Table> table) {
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
  useEffect(() => () => print('disposed table row'), [0]);

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
              width: table.columns[columnID].nonnull.width.read(reader),
              decoration: BoxDecoration(border: Border(right: BorderSide())),
              child: table.columns[columnID].nonnull.rows.cases(
                reader,
                stringColumn: (column) => StringField(
                  column: table.columns[columnID].nonnull,
                  string: column.values[rowID],
                ),
                booleanColumn: (column) => Checkbox(
                  onChanged: (newValue) => column.values[rowID].set(newValue!),
                  value: column.values[rowID].orElse(false).read(reader),
                ),
                multiselectColumn: (column) => Container(),
                linkColumn: (column) => Container(),
                dateColumn: (column) => Container(),
                intColumn: (column) => Container(),
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
              child: NewColumnButton(null),
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
  required Cursor<model.Column> column,
  required Cursor<String?> string,
}) {
  final isOpen = useState(false);
  final textStyle = Theme.of(context).textTheme.bodyText2;
  final padding = EdgeInsetsDirectional.only(top: 5, bottom: 5, start: 5, end: 0);
  final maxWidth = 200.0;
  final focusRef = useRef(Pair([true, false], FocusNode()));
  useEffect(
    () {
      return () {
        if (focusRef.value.first[0]) focusRef.value.second.dispose();
        focusRef.value.first[1] = true;
      };
    },
    [0],
  );

  return ReplacerDropdown(
    isOpen: isOpen,
    dropdownFocus: focusRef.value.second,
    dropdownBuilder: (context, replacedSize) => ScrollConfiguration(
      behavior: ScrollBehavior().copyWith(scrollbars: false),
      child: ModifiedIntrinsicWidth(
        modification: 2,
        child: Container(
          constraints: BoxConstraints(
            minWidth: replacedSize.width - 2,
            maxWidth: math.max(replacedSize.width - 2, maxWidth),
            minHeight: replacedSize.height,
            maxHeight: replacedSize.height,
          ),
          child: Container(
            child: HookBuilder(
              builder: (_) {
                useEffect(
                  () {
                    focusRef.value.first[0] = false;
                    return () {
                      if (focusRef.value.first[1]) {
                        focusRef.value.second.dispose();
                      }
                      focusRef.value.first[0] = true;
                    };
                  },
                  [0],
                );

                return BoundTextFormField(
                  string.orElse(''),
                  style: textStyle,
                  focusNode: focusRef.value.second,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    focusedBorder: InputBorder.none,
                    contentPadding: padding,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
    child: TextButton(
      onPressed: () {
        isOpen.value = !isOpen.value;
      },
      child: Container(
        padding: padding,
        alignment: Alignment.topLeft,
        child: Text(
          string.orElse('').read(reader),
          style: textStyle,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}
