import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
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
                        final getWidget = column.columnType
                            .recordAccess<model.ColumnGetWidgetFn>('getWidget')
                            .read(ctx);
                        final getData = column.columnType
                            .recordAccess<model.ColumnGetDataFn>('getData')
                            .read(ctx);
                        final data =
                            getData(Dict({'rowID': rowID, 'config': column.config}), ctx: ctx);
                        return getWidget(Dict({'rowData': data, 'config': column.config}),
                            ctx: ctx);
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
