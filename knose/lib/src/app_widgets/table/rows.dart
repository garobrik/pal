import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:reorderables/reorderables.dart';
import 'package:knose/model.dart' as model;

part 'rows.g.dart';

@reader_widget
Widget _tableRows({
  required Ctx ctx,
  required Cursor<model.Table> table,
}) {
  final scrollController = useScrollController();

  return ReorderableColumn(
    scrollController: scrollController,
    onReorder: (old, nu) {
      table.rowIDs.atomically((rowIDs) {
        rowIDs.insert(nu < old ? nu : nu + 1, rowIDs[old].read(Ctx.empty));
        rowIDs.remove(nu < old ? old + 1 : old);
      });
    },
    children: [
      for (final rowID in table.rowIDs.read(ctx))
        TableRow(
          ctx: ctx,
          table: table,
          rowID: rowID,
          key: ValueKey(rowID),
        ),
    ],
  );
}

@reader_widget
Widget _tableRow(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<model.Table> table,
  required model.RowID rowID,
  bool enabled = true,
  bool trailingNewColumnSpace = true,
}) {
  final isHovered = useCursor(false);

  return MouseRegion(
    opaque: false,
    onEnter: (_) => isHovered.set(true),
    onHover: (_) => isHovered.set(true),
    onExit: (_) => isHovered.set(false),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ReaderWidget(
          ctx: ctx,
          builder: (_, ctx) => isHovered.read(ctx) && table.rowViews.length.read(ctx) > 0
              ? OpenRowButton(
                  widgetID: table.rowViews[0].read(ctx),
                  ctx: ctx.withTable(table).withRow(rowID),
                )
              : const OpenRowButton(),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide())),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final columnID in table.columnIDs.read(ctx))
                  Container(
                    key: ValueKey(columnID),
                    width: table.columns[columnID].whenPresent.width.read(ctx),
                    decoration: const BoxDecoration(border: Border(right: BorderSide())),
                    child: ReaderWidget(
                      ctx: ctx,
                      builder: (_, ctx) {
                        final column = table.columns[columnID].whenPresent;
                        final type = column.type.read(ctx);
                        if (type is model.TextType) {
                          return StringField(
                            ctx: ctx,
                            string: column.values[rowID],
                            enabled: enabled,
                          );
                        } else if (type is model.BooleanType) {
                          return Checkbox(
                            onChanged: !enabled
                                ? null
                                : (newValue) => column.values[rowID] = newValue!
                                    ? const Optional(model.PalValue(model.booleanType, true))
                                    : const Optional.none(),
                            value: column.values[rowID]
                                .read(ctx)
                                .map<dynamic>((p0) => p0.value)
                                .orElse(false) as bool,
                          );
                        } else if (type is model.NumberType) {
                          return NumField(
                            ctx: ctx,
                            number: column.values[rowID],
                            enabled: enabled,
                          );
                        } else {
                          return Container();
                        }
                        // return table.columns[columnID].whenPresent.type.cases(
                        //   reader,
                        //   selectColumn: (column) => SelectField(
                        //     column: column,
                        //     row: column.values[rowID],
                        //     enabled: enabled,
                        //   ),
                        //   multiselectColumn: (column) => MultiselectField(
                        //     column: column,
                        //     row: column.values[rowID].orElse(const CSet()),
                        //     enabled: enabled,
                        //   ),
                        //   linkColumn: (column) => LinkField(
                        //     ctx: ctx,
                        //     column: column,
                        //     rowCursor: column.values[rowID],
                        //     enabled: enabled,
                        //   ),
                        //   dateColumn: (column) => Container(),
                        //   pageColumn: (column) => Container(),
                        // );
                      },
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
        ),
      ],
    ),
  );
}

// TODO: make work with tab nav
@reader_widget
Widget _openRowButton(
  BuildContext context, {
  model.WidgetID? widgetID,
  Ctx ctx = Ctx.empty,
}) {
  return AnimatedOpacity(
    opacity: widgetID != null ? 1 : 0,
    duration: const Duration(milliseconds: 300),
    child: TextButton(
      style: ButtonStyle(padding: MaterialStateProperty.all(EdgeInsets.zero)),
      onPressed: (widgetID == null)
          ? null
          : () {
              Navigator.pushNamed(
                context,
                '',
                arguments: model.WidgetRoute(
                  widgetID,
                  ctx: ctx,
                ),
              );
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.open_in_full,
            size: 16,
          ),
          // Text('Open'),
        ],
      ),
    ),
  );
}

@reader_widget
Widget _linkField(
  Reader reader,
  BuildContext context, {
  required Ctx ctx,
  required Cursor<model.Column> column,
  required Cursor<Optional<model.RowID>> rowCursor,
  bool enabled = true,
}) {
  final isOpen = useCursor(false);
  const model.TableID? tableID = null; //column.table.read(ctx) as model.TableID?;
  String? title(Reader reader) {
    final row = rowCursor.read(ctx).unwrap;
    if (row == null || tableID == null) return null;
    final table = ctx.db.get(tableID).whenPresent;
    return table.columns[table.titleColumn.read(ctx)].whenPresent.values[row].read(ctx).unwrap
        as String?;
  }

  final focusForRow = useMemoized(() {
    final map = <model.RowID, FocusNode>{};
    return (model.RowID rowID) => map.putIfAbsent(rowID, () => FocusNode());
  });
  FocusNode? currentFocus;
  if (tableID != null) {
    final table = ctx.db.get(tableID).whenPresent;
    final length = table.rowIDs.length.read(ctx);
    if (length > 0) {
      currentFocus = focusForRow(table.rowIDs[0].read(ctx));
    }
  }

  return DeferredDropdown(
    offset: const Offset(-1, -1),
    isOpen: isOpen,
    dropdownFocus: currentFocus,
    childAnchor: Alignment.topLeft,
    dropdown: ReaderWidget(
      ctx: ctx,
      builder: (_, ctx) {
        final table = ctx.db.get(tableID!).whenPresent;
        final width = table.columns.keys
            .read(ctx)
            .map(
              (colID) => table.columns[colID].whenPresent.width.read(ctx),
            )
            .reduce((a, b) => a + b);

        return Container(
          constraints: BoxConstraints(maxWidth: width),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: table.rowIDs.length.read(ctx),
            itemBuilder: (_, index) => ReaderWidget(
              ctx: ctx,
              builder: (_, ctx) {
                final rowID = table.rowIDs[index].read(ctx);
                return TextButton(
                  focusNode: focusForRow(rowID),
                  style: ButtonStyle(
                    alignment: Alignment.centerLeft,
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () => rowCursor.set(Optional(rowID)),
                  child: TableRow(
                    ctx: ctx,
                    table: table,
                    rowID: rowID,
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
      style: const ButtonStyle(alignment: Alignment.centerLeft),
      onPressed: (tableID == null || !enabled) ? null : () => isOpen.set(true),
      child: Text(
        title(reader) ?? '',
        style: const TextStyle(decoration: TextDecoration.underline),
      ),
    ),
  );
}
