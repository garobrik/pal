import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
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
  final isOpen = useCursor(false);

  return Actions(
    actions: {
      ConfigureNodeViewIntent: CallbackAction<ConfigureNodeViewIntent>(
        onInvoke: (_) => isOpen.set(true),
      ),
    },
    child: Shortcuts(
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.keyS, control: true): const ConfigureNodeViewIntent(),
      },
      child: Dropdown(
        isOpen: isOpen,
        dropdown: NodeViewConfigWidget(
          state: state,
          view: nodeView,
        ),
        child: viewNode.builder(state, node),
      ),
    ),
  );
}

@reader_widget
Widget _nodeViewConfigWidget({
  required Cursor<model.State> state,
  required Cursor<model.NodeView> view,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        autofocus: true,
        onPressed: () {
          if (view.read(null) is! model.NodeView<model.Text>) {
            view.set(
              model.NodeView.from(
                id: view.id.read(null),
                builder: TextBuilder(),
                nodeID: state.addNode(model.Text()),
              ),
            );
          }
        },
        child: Text('Text node'),
      ),
      TextButton(
        onPressed: () {
          if (view.read(null) is! model.NodeView<model.List>) {
            view.set(
              model.NodeView.from(
                id: view.id.read(null),
                builder: ListBuilder(),
                nodeID: state.addNode(
                  model.List(
                    nodeViews: Vec([state.addTextView()]),
                  ),
                ),
              ),
            );
          }
        },
        child: Text('List node'),
      ),
    ],
  );
}
