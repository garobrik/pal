import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/table.dart' hide Column;
import 'package:knose/table.dart' as table;
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'table.g.dart';

final tableRefIDID = pal.MemberID();
final tableRefDef = pal.DataDef.record(
  name: 'TableData',
  members: [
    pal.Member(id: tableRefIDID, name: 'table', type: tableIDDef.asType()),
  ],
);

final tableWidget = widget.def.instantiate({
  widget.nameID: 'Table',
  widget.typeID: tableRefDef.asType(),
  widget.defaultDataID: (Ctx ctx, Object _) {
    final table = Table.newDefault();
    ctx.db.update(table.id, table);

    return tableRefDef.instantiate({
      tableRefIDID: table.id,
    });
  },
  widget.buildID: MainTableWidget.new,
});

@reader
Widget _mainTableWidget(BuildContext context, Ctx ctx, Object data) {
  final tableID = (data as GetCursor<Object>).recordAccess(tableRefIDID).read(ctx) as TableID;
  final table = ctx.db.get(tableID).whenPresent;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (ctx.widgetMode == widget.Mode.edit)
        Row(
          children: [
            const OpenRowButton(),
            TableConfig(ctx: ctx, table: table),
          ],
        ),
      Expanded(
        child: Scrollable2D(
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const OpenRowButton(),
                    ClipRectNotBottom(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).canvasColor,
                          boxShadow: const [BoxShadow(blurRadius: 4)],
                          border: const Border(top: BorderSide()),
                        ),
                        child: TableHeader(table, ctx: ctx),
                      ),
                    ),
                  ],
                ),
                TableRows(ctx: ctx, table: table),
                if (ctx.widgetMode == widget.Mode.edit)
                  Row(
                    children: [
                      const OpenRowButton(),
                      ElevatedButton(
                        onPressed: () => table.addRow(),
                        focusNode: ctx.defaultFocus,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [Icon(Icons.add), Text('New row')],
                        ),
                      ),
                    ],
                  )
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
