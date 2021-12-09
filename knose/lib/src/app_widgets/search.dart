import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

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
          .where<model.PalValue>(
        ctx: ctx,
        namespace: model.WidgetID.namespace,
        predicate: (_) => true,
      )
          .map((widget) {
        const title = 'temp';
        final widgetID = widget.recordAccess<model.WidgetID>('id').read(ctx);
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
            children: const [
              Icon(Icons.menu),
              Text(title),
            ],
          ),
        );
      }),
    ],
  );
}
