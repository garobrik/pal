import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/table.dart' hide Column;
import 'package:knose/table.dart' as table;
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'table.g.dart';

final _tableID = pal.MemberID();
final _titleID = pal.MemberID();
final tableRecordDef = pal.DataDef.record(
  name: 'TableData',
  members: [
    pal.Member(id: _tableID, name: 'table', type: tableIDDef.asType()),
    pal.Member(id: _titleID, name: 'title', type: pal.text),
  ],
);

final tableWidget = widget.def.instantiate({
  widget.nameID: 'Table',
  widget.typeID: tableRecordDef.asType(),
  widget.defaultDataID: (Ctx ctx, Object _) {
    final table = Table.newDefault();
    ctx.db.update(table.id, table);

    return tableRecordDef.instantiate({
      _tableID: table.id,
      _titleID: 'Untitled page',
    });
  },
  widget.buildID: MainTableWidget.new,
});

@reader
Widget _mainTableWidget(BuildContext context, Ctx ctx, Object data) {
  final tableID = (data as GetCursor<Object>).recordAccess(_tableID).read(ctx) as TableID;
  final table = ctx.db.get(tableID).whenPresent;

  return Container(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const OpenRowButton(),
            Container(
              padding: const EdgeInsetsDirectional.only(bottom: 20),
              child: IntrinsicWidth(
                child: BoundTextFormField(
                  table.title,
                  ctx: ctx,
                  style: Theme.of(context).textTheme.headline6,
                ),
              ),
            ),
          ],
        ),
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
                  Row(
                    children: [
                      const OpenRowButton(),
                      ElevatedButton(
                        onPressed: () => table.addRow(),
                        focusNode: ctx.defaultFocus,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: const [Icon(Icons.add), Text('New row')],
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
    ),
  );
}
