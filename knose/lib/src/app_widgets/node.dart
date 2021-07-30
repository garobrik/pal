import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

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
      body: nodeViewID.build(state),
      replaceRouteOnPush: false,
    ),
  );
}
