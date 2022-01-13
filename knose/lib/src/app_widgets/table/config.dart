import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;
import 'package:flutter_hooks/flutter_hooks.dart';

part 'config.g.dart';

@reader
Widget _tableConfig(
  BuildContext context, {
  required Cursor<model.Table> table,
  required Ctx ctx,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButtonDropdown(
        dropdown: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final rowView in table.rowViews.values(ctx))
                ReaderWidget(
                  ctx: ctx,
                  builder: (_, ctx) {
                    final widgetDef = ctx.db.get(rowView.read(ctx)).whenPresent;
                    final title = widgetDef
                        .recordAccess(widget.instanceDataID)
                        .recordAccess(pageTitleID)
                        .read(ctx) as String;

                    return TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '',
                        arguments: model.WidgetRoute(
                          rowView.read(ctx),
                          ctx: ctx.withTable(table),
                        ),
                      ),
                      child: Row(children: [Text(title)]),
                    );
                  },
                ),
              TextButton(
                onPressed: () {
                  final newPage = widget.defaultInstance(ctx, pageWidget);
                  final widgetID = newPage.recordAccess(widget.instanceIDID) as widget.ID;
                  ctx.db.update(widgetID, newPage);

                  table.rowViews.add(widgetID);
                  Navigator.pushNamed(
                    context,
                    '',
                    arguments: model.WidgetRoute(
                      widgetID,
                      ctx: ctx.withTable(table),
                    ),
                  );
                },
                child: Row(
                  children: const [Icon(Icons.add), Text('New row view')],
                ),
              )
            ],
          ),
        ),
        child: Row(
          children: const [
            Text('Row views'),
            Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    ],
  );
}
