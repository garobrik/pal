import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;

part 'search_dialog.g.dart';

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
