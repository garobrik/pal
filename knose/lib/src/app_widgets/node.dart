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
      arguments: model.NodeRoute(nodeViewID, ctx: ctx),
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
  final child = nodeView.build(
        ctx: ctx,
        defaultFocus: defaultFocus,
        reader: reader,
      ) ??
      const Text('null fields :(');

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
Widget _nodeViewConfigWidget(
  Reader reader, {
  required model.Ctx ctx,
  required Cursor<model.NodeView> view,
}) {
  final isOpen = useCursor(false);

  return IntrinsicWidth(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final fieldName in view.fields.keys.read(reader))
          ReaderWidget(
            builder: (_, reader) {
              final fieldIsOpen = useCursor(false);
              return DeferredDropdown(
                isOpen: fieldIsOpen,
                dropdown: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final dataSource in ctx.ofType<model.DataSource>())
                        for (final datum in dataSource.data.read(reader))
                          TextButton(
                            onPressed: () => view.fields[fieldName] = Optional(datum),
                            child: Text(datum.name(reader, ctx).read(reader)),
                          ),
                    ],
                  ),
                ),
                child: TextButton(
                  onPressed: () => fieldIsOpen.set(!fieldIsOpen.read(null)),
                  child: Text(
                    '$fieldName: ' +
                        view.fields[fieldName].whenPresent
                            .read(reader)
                            .name(reader, ctx)
                            .read(reader),
                  ),
                ),
              );
            },
          ),
        DeferredDropdown(
          isOpen: isOpen,
          childAnchor: Alignment.topRight,
          dropdown: IntrinsicWidth(
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
          ),
          child: TextButton(
            onPressed: () => isOpen.set(!isOpen.read(null)),
            child: const Text('View type'),
          ),
        ),
      ],
    ),
  );
}
