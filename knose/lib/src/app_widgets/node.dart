import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'node.g.dart';

Route<Null> generateNodeRoute<T extends model.TitledNode>(
  Cursor<model.State> state,
  model.NodeID<model.NodeView<T>> nodeViewID,
) {
  final nodeView = state.getNode(nodeViewID);
  final node = state.getNode(nodeView.nodeID.read(null));

  return MaterialPageRoute(
    settings: RouteSettings(name: node.title.read(null), arguments: model.NodeRoute(nodeViewID)),
    builder: (_) => MainScaffold(
      title: EditableScaffoldTitle(node.title),
      state: state,
      body: NodeViewWidget(state, Cursor(nodeViewID)),
      replaceRouteOnPush: false,
    ),
  );
}

@reader_widget
Widget _nodeViewWidget(
  Reader reader,
  Cursor<model.State> state,
  Cursor<model.NodeID<model.NodeView>> nodeViewID,
) {
  final nodeView = state.getNode(nodeViewID.read(reader));
  final viewNode = nodeView.builder.read(reader);
  final node = state.getNode(nodeView.nodeID.read(reader));

  return viewNode.builder(state, node);
}
