import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'search.g.dart';

Route<void> generateSearchRoute(Ctx ctx) {
  return MaterialPageRoute(
    settings: const RouteSettings(name: 'search', arguments: model.SearchRoute()),
    builder: (_) => MainScaffold(
      ctx: ctx,
      replaceRouteOnPush: false,
      body: SearchPage(ctx: ctx),
    ),
  );
}

@reader
Widget _searchPage(
  BuildContext context, {
  required Ctx ctx,
}) {
  final searchText = useCursor('');

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(
        child: Container(
          margin: const EdgeInsetsDirectional.fromSTEB(100, 50, 100, 50),
          decoration: BoxDecoration(
            boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.grey)],
            borderRadius: BorderRadius.circular(7),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 30),
              Expanded(
                child: BoundTextFormField(
                  searchText,
                  ctx: ctx,
                  autofocus: true,
                  decoration: const InputDecoration(
                    filled: false,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsetsDirectional.only(start: 0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ...ctx.db
          .where<Object>(
        ctx: ctx,
        namespace: widget.RootID.namespace,
        predicate: (root) => root.recordAccess(widget.rootTopLevelID).read(ctx) as bool,
      )
          .map((widgetDef) {
        final title = widgetDef.recordAccess(widget.rootNameID).read(ctx) as String;
        final widgetID = widgetDef.recordAccess(widget.rootIDID).read(ctx) as pal.ID;
        return TextButton(
          key: ValueKey(widgetID),
          onPressed: () {
            Navigator.pushNamed(
              context,
              '',
              arguments: model.WidgetRoute(widgetID),
            );
          },
          child: Row(
            children: [
              const Icon(Icons.menu),
              Text(title),
            ],
          ),
        );
      }),
    ],
  );
}
