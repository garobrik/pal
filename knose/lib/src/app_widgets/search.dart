import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'search.g.dart';

Route<void> generateSearchRoute(model.Ctx ctx) {
  return MaterialPageRoute(
    settings: const RouteSettings(name: 'search', arguments: model.SearchRoute()),
    builder: (_) => MainScaffold(
      ctx: ctx,
      replaceRouteOnPush: false,
      body: SearchPage(ctx),
    ),
  );
}

@reader_widget
Widget _searchPage(
  BuildContext context,
  Reader reader,
  model.Ctx ctx,
) {
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
      ...ctx.state.nodes.keys.read(reader).expand((nodeID) {
        if (nodeID is! model.NodeID<model.NodeView>) {
          return [];
        }
        final nodeView = ctx.state.getNode(nodeID);
        final builder = nodeView.nodeBuilder.read(reader);
        if (builder is! model.TopLevelNodeBuilder) {
          return [];
        }
        final fields = Dict({
          for (final field in nodeView.fields.keys.read(reader))
          field: nodeView.fields[field].whenPresent.read(reader).build(reader, ctx)!
        });
        final title =
            builder.title(ctx: ctx, fields: fields).read(reader);
        return [
          if (title.toLowerCase().startsWith(searchText.read(reader)))
            TextButton(
              key: ValueKey(nodeID),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '',
                  arguments: model.NodeRoute(nodeID),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.menu),
                  Text(title),
                ],
              ),
            )
        ];
      }),
    ],
  );
}
