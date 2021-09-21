import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;
import 'package:flutter_hooks/flutter_hooks.dart';

part 'config.g.dart';

@reader_widget
Widget _tableConfig(
  BuildContext context,
  Reader reader, {
  required Cursor<model.Table> table,
  required model.Ctx ctx,
}) {
  final isOpen = useCursor(false);

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DeferredDropdown(
        isOpen: isOpen,
        dropdown: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final rowView in table.rowViews.values(reader))
              ReaderWidget(
                builder: (_, reader) {
                  final nodeView = ctx.state.getNode(rowView.read(reader));
                  final title = nodeView.title(ctx: ctx, reader: reader)!;

                  return TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '',
                      arguments: model.NodeRoute(
                        rowView.read(reader),
                        ctx: ctx.withTable(table),
                      ),
                    ),
                    child: Text(title.read(reader)),
                  );
                },
              ),
            TextButton(
              onPressed: () {
                final nodeViewID = const PageBuilder().addView(ctx.state);
                table.rowViews.add(nodeViewID);
                Navigator.pushNamed(
                  context,
                  '',
                  arguments: model.NodeRoute(
                    nodeViewID,
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
        child: TextButton(
          onPressed: () => isOpen.set(!isOpen.read(null)),
          child: Row(
            children: const [
              Text('Row views'),
              Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    ],
  );
}
