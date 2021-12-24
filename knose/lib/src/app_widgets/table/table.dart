import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';

part 'table.g.dart';

final tableWidget = Dict({
  model.widgetNameID: 'Table',
  model.widgetFieldsID: Dict({
    'table': model.tableIDDef.asType(),
    'title': model.textType,
  }),
  model.widgetDefaultFieldsID: ({required Ctx ctx}) {
    final table = model.Table.newDefault();
    ctx.db.update(table.id, table);

    return Dict({
      'table': model.PalValue(model.tableIDDef.asType(), table.id),
      'title': const model.PalValue(model.textType, 'Untitled page'),
    });
  },
  model.widgetBuildID: MainTableWidget.new,
});

@reader
Widget _mainTableWidget(
  BuildContext context,
  Dict<String, Cursor<Object>> fields, {
  required Ctx ctx,
}) {
  final tableID = fields['table'].unwrap!.cast<model.TableID>().read(ctx);
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
