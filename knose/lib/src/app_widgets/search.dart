import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'search.g.dart';

Route<Null> generateSearchRoute(Cursor<model.State> state) {
  return MaterialPageRoute(
    settings: RouteSettings(name: 'search', arguments: model.SearchRoute()),
    builder: (_) => MainScaffold(
      state: state,
      replaceRouteOnPush: false,
      body: SearchPage(state),
    ),
  );
}

@reader_widget
Widget _searchPage(BuildContext context, Reader reader, Cursor<model.State> state) {
  final searchText = useCursor('');

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(
        child: Container(
          margin: EdgeInsetsDirectional.fromSTEB(100, 100, 100, 50),
          decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 30,
              ),
              Expanded(
                child: BoundTextFormField(
                  searchText,
                  autofocus: true,
                  decoration: InputDecoration(
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
      ...state.nodes.keys.read(reader).expand((nodeID) {
        if (nodeID is! model.NodeID<model.TitledNode>) return [];
        final node = state.getNode(nodeID);
        return [
          if (node.title.read(reader).toLowerCase().startsWith(searchText.read(reader)))
            TextButton(
              key: ValueKey(nodeID),
              onPressed: () {
                // Navigator.pushNamed(
                //   context,
                //   '',
                //   arguments: model.NodeRoute(node.id),
                // );
              },
              child: Row(
                children: [
                  Icon(Icons.menu),
                  Text(node.title.read(reader)),
                ],
              ),
            )
        ];
      }),
    ],
  );
}

@reader_widget
Widget _searchDialog(Reader reader, Cursor<model.State> state) {
  final searchText = useCursor('');

  return Shortcuts(
    shortcuts: {LogicalKeySet(LogicalKeyboardKey.escape): DismissIntent()},
    child: Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: BoundTextFormField(
                  searchText,
                  autofocus: true,
                  decoration: InputDecoration(
                    filled: false,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              Icon(Icons.search),
            ],
          ),
          Divider(height: 0),
          ...state.nodes.keys.read(reader).expand((nodeID) {
            final node = state.getNode(nodeID).read(reader);
            return [
              if (node is model.TitledNode)
                TextButton(
                  key: ValueKey(nodeID),
                  onPressed: () {},
                  child: Row(
                    children: [
                      Icon(Icons.menu),
                      Text(node.title),
                    ],
                  ),
                )
            ];
          }),
        ],
      ),
    ),
  );
}
