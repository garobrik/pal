import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infra_widgets/deferred_paint.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/shortcuts.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/table.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'scaffold.g.dart';

@reader
Widget _mainScaffold(
  BuildContext context, {
  required Ctx ctx,
  required Widget body,
  required bool replaceRouteOnPush,
  Widget? title,
}) {
  return KnoseActions(
    child: Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              // automaticallyImplyLeading: false,
              title: title,
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black38)],
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            BottomButton(
              text: 'New page',
              icon: Icons.post_add,
              onPressed: () {
                final newPage = widget.rootInstance(
                  ctx: ctx,
                  widget: pageWidget,
                  name: 'Untitled page',
                  mode: const Optional(widget.Mode.view),
                );
                final widgetID = newPage.recordAccess(widget.rootIDID) as widget.RootID;
                ctx.db.update(widgetID, newPage);

                if (replaceRouteOnPush) {
                  Navigator.pushReplacementNamed(
                    context,
                    '',
                    arguments: model.WidgetRoute(
                      widgetID,
                      ctx: ctx,
                    ),
                  );
                } else {
                  Navigator.pushNamed(
                    context,
                    '',
                    arguments: model.WidgetRoute(
                      widgetID,
                      ctx: ctx,
                    ),
                  );
                }
              },
            ),
            BottomButton(
              text: 'New table',
              icon: Icons.playlist_add,
              onPressed: () {
                final newTable = widget.rootInstance(
                  ctx: ctx,
                  widget: tableWidget,
                  name: 'Untitled table',
                  mode: const Optional(widget.Mode.edit),
                );
                final widgetID = newTable.recordAccess(widget.rootIDID) as widget.RootID;
                ctx.db.update(widgetID, newTable);

                if (replaceRouteOnPush) {
                  Navigator.pushReplacementNamed(
                    context,
                    '',
                    arguments: model.WidgetRoute(
                      widgetID,
                      ctx: ctx,
                    ),
                  );
                } else {
                  Navigator.pushNamed(
                    context,
                    '',
                    arguments: model.WidgetRoute(
                      widgetID,
                      ctx: ctx,
                    ),
                  );
                }
              },
            ),
            BottomButton(
              text: 'Search',
              icon: Icons.search,
              onPressed: () {
                if (replaceRouteOnPush) {
                  Navigator.pushReplacementNamed(
                    context,
                    '',
                    arguments: const model.SearchRoute(),
                  );
                } else {
                  Navigator.pushNamed(
                    context,
                    '',
                    arguments: const model.SearchRoute(),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: DeferredPaintTarget(child: body),
    ),
  );
}

@reader
Widget _editableScaffoldTitle(BuildContext context, Cursor<String> title) {
  return IntrinsicWidth(
    child: BoundTextFormField(
      title,
      ctx: Ctx.empty,
      style: Theme.of(context).textTheme.titleLarge,
      decoration: const InputDecoration(hintText: 'title'),
    ),
  );
}

@reader
Widget _scaffoldTitle(Ctx ctx, BuildContext context, GetCursor<String> title) {
  return Text(
    title.read(ctx),
    style: Theme.of(context).textTheme.titleLarge,
  );
}

@reader
Widget _bottomButton({
  required void Function() onPressed,
  required IconData icon,
  required String text,
}) {
  return ElevatedButton(
    onPressed: onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          Text(text),
        ],
      ),
    ),
  );
}
