import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart';
import 'package:knose/table.dart' hide Column;
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'config.g.dart';

@reader
Widget _tableConfig(
  BuildContext context, {
  required Cursor<Table> table,
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
                    final title = widgetDef.recordAccess(widget.rootNameID).read(ctx) as String;

                    return TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '',
                        arguments: WidgetRoute(
                          rowView.read(ctx),
                          ctx: ctx.withTable(table).withWidgetMode(widget.Mode.edit),
                        ),
                      ),
                      child: Row(children: [Text(title)]),
                    );
                  },
                ),
              TextButton(
                onPressed: () {
                  final newPage = widget.rootInstance(
                    ctx: ctx,
                    widget: pageWidget,
                    name: 'Untitled row view',
                    mode: const Optional<widget.Mode>.none(),
                    topLevel: false,
                  );
                  final widgetID = newPage.recordAccess(widget.rootIDID) as widget.RootID;
                  ctx.db.update(widgetID, newPage);

                  table.rowViews.add(widgetID);
                  Navigator.pushNamed(
                    context,
                    '',
                    arguments: WidgetRoute(
                      widgetID,
                      ctx: ctx.withTable(table).withWidgetMode(widget.Mode.edit),
                    ),
                  );
                },
                child: const Row(
                  children: [Icon(Icons.add), Text('New row view')],
                ),
              )
            ],
          ),
        ),
        child: const Row(
          children: [
            Text('Row views'),
            Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    ],
  );
}
