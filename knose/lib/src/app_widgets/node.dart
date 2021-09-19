import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;

part 'node.g.dart';

Route generateNodeRoute(
  model.Ctx ctx,
  model.NodeID<model.NodeView> nodeViewID,
) {
  return MaterialPageRoute<void>(
    settings: RouteSettings(
      arguments: model.NodeRoute(nodeViewID),
    ),
    builder: (_) => MainScaffold(
      ctx: ctx,
      body: NodeViewWidget(
        ctx: ctx,
        nodeViewID: Cursor(nodeViewID),
      ),
      replaceRouteOnPush: false,
    ),
  );
}

@reader_widget
Widget _nodeViewWidget(
  Reader reader, {
  required model.Ctx ctx,
  required Cursor<model.NodeID<model.NodeView>> nodeViewID,
  FocusNode? defaultFocus,
}) {
  final nodeView = ctx.state.getNode(nodeViewID.read(reader));
  final fields = Dict({
    for (final field in nodeView.fields.keys.read(reader))
      field: nodeView.fields[field].whenPresent.read(reader).build(reader, ctx)
  });
  late final Widget child;
  if (fields.every((entry) => entry.value != null)) {
    final nonnullFields = Dict(
      {for (final field in fields) field.key: field.value!},
    );

    child = nodeView.nodeBuilder.read(reader).build(
          ctx: ctx,
          fields: nonnullFields,
          defaultFocus: defaultFocus,
        );
  } else {
    child = const Text('null fields :(');
  }

  final isOpen = useCursor(false);
  final dropdownFocus = useFocusNode();

  return Actions(
    actions: {
      ConfigureNodeViewIntent: CallbackAction<ConfigureNodeViewIntent>(
        onInvoke: (_) => isOpen.set(true),
      ),
    },
    child: Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.keyS, LogicalKeyboardKey.control):
            const ConfigureNodeViewIntent(),
      },
      child: DeferredDropdown(
        dropdownFocus: dropdownFocus,
        isOpen: isOpen,
        childAnchor: Alignment.bottomLeft,
        dropdown: NodeViewConfigWidget(
          ctx: ctx,
          view: nodeView,
        ),
        child: child,
      ),
    ),
  );
}

const builders = [
  TableBuilder(),
  ListBuilder(),
  TextBuilder(),
  PageBuilder(),
];

@reader_widget
Widget _nodeViewConfigWidget({
  required model.Ctx ctx,
  required Cursor<model.NodeView> view,
}) {
  return IntrinsicWidth(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final builder in builders)
          TextButton(
            onPressed: () {
              if (view.nodeBuilder.read(null) != builder) {
                view.fields.set(builder.makeFields(ctx.state, view.id.read(null)));
                view.nodeBuilder.set(builder);
              }
            },
            child: Row(children: [Text('${builder.runtimeType}')]),
          ),
      ],
    ),
  );
}
