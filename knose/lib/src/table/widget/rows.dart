import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:reorderables/reorderables.dart';
import 'package:knose/model.dart';
import 'package:knose/table.dart' hide Column;
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'rows.g.dart';

@reader
Widget _tableRows({
  required Ctx ctx,
  required Cursor<Table> table,
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

@reader
Widget _tableRow(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<Table> table,
  required RowID rowID,
}) {
  final isHovered = useCursor(false);
  final hasFocus = useCursor(false);
  final showOpenRowButton = useMemoized(
    () => GetCursor.compute(
      (ctx) => ctx.widgetMode == widget.Mode.edit && isHovered.read(ctx) || hasFocus.read(ctx),
      ctx: ctx,
      compare: true,
    ),
    [ctx],
  );

  return Focus(
    skipTraversal: true,
    onFocusChange: hasFocus.set,
    child: MouseRegion(
      opaque: false,
      onEnter: (_) => isHovered.set(true),
      onHover: (_) => isHovered.set(true),
      onExit: (_) => isHovered.set(false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (ctx.widgetMode == widget.Mode.edit)
            ReaderWidget(
              ctx: ctx,
              builder: (_, ctx) => table.rowViews.length.read(ctx) > 0
                  ? OpenRowButton(
                      show: showOpenRowButton,
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
                          final palImpl = pal.findImpl(
                            ctx,
                            tableDataDef.asType(
                              {tableDataImplementerID: column.dataImpl.type.read(ctx)},
                            ),
                          )!;
                          final getWidget = palImpl.interfaceAccess(ctx, tableDataGetWidgetID);
                          final getDefault = palImpl.interfaceAccess(ctx, tableDataGetDefaultID);
                          final defaultValue = getDefault.callFn(ctx, column.dataImpl.value);
                          return getWidget.callFn(
                            ctx,
                            Dict({
                              'rowData': column.data[rowID].orElse(defaultValue),
                              'impl': column.dataImpl.value,
                            }),
                          ) as Widget;
                        },
                      ),
                    ),
                  if (ctx.widgetMode == widget.Mode.edit)
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
    ),
  );
}

// TODO: make work with tab nav
@reader
Widget _openRowButton(
  BuildContext context, {
  GetCursor<bool> show = const GetCursor(false),
  widget.RootID? widgetID,
  Ctx ctx = Ctx.empty,
}) {
  return AnimatedOpacity(
    alwaysIncludeSemantics: true,
    opacity: widgetID != null && show.read(ctx) ? 1 : 0,
    duration: const Duration(milliseconds: 300),
    child: TextButton(
      style: ButtonStyle(padding: MaterialStateProperty.all(EdgeInsets.zero)),
      onPressed: (widgetID == null)
          ? null
          : () {
              Navigator.pushNamed(
                context,
                '',
                arguments: WidgetRoute(
                  widgetID,
                  ctx: ctx.withWidgetMode(widget.Mode.view),
                ),
              );
            },
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
