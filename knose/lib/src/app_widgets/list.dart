import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'list.g.dart';

@immutable
@reify
class ListBuilder with model.TypedNodeBuilder<model.List> {
  const ListBuilder();

  @override
  model.NodeBuilderFn<model.List> get buildTyped => ListWidget.tearoff;
}

@reader_widget
Widget _listWidget(
  Reader reader,
  BuildContext context, {
  required Cursor<model.State> state,
  required Cursor<model.List> node,
  FocusNode? defaultFocus,
}) {
  final focusForID = useMemoized(() {
    final foci = <model.NodeID<model.NodeView>, FocusNode>{};
    return (model.NodeID<model.NodeView> id) {
      if (node.nodeViews[0].read(reader) == id) {
        return defaultFocus ?? foci.putIfAbsent(id, () => FocusNode());
      }
      return foci.putIfAbsent(id, () => FocusNode());
    };
  });

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final index in range(node.nodeViews.length.read(reader)))
        Padding(
          key: ValueKey(node.nodeViews[index].read(reader)),
          padding: index == 0
              ? EdgeInsetsDirectional.only(start: 4, end: 4, bottom: 4)
              : EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(top: 10, end: 5),
                child: Icon(Icons.circle, size: 10),
              ),
              Expanded(
                child: Material(
                  elevation: 2,
                  child: Actions(
                    actions: {
                      NewNodeBelowIntent: NewNodeBelowAction(
                        onInvoke: (_) {
                          late final model.NodeID<model.NodeView> id;
                          node.nodeViews.insert(
                            index + 1,
                            id = state.addTextView(),
                          );
                          focusForID(id).requestFocus();
                        },
                      ),
                      DeleteNodeIntent: CallbackAction<DeleteNodeIntent>(
                        onInvoke: (_) {
                          if (node.nodeViews.length.read(null) > 1) {
                            node.nodeViews.remove(index);
                            focusForID(
                              node.nodeViews[max(index - 1, 0)].read(null),
                            ).requestFocus();
                          } else {
                            Actions.invoke(
                              context,
                              DeleteNodeIntent(),
                            );
                          }
                        },
                      ),
                    },
                    child: NodeViewWidget(
                      state: state,
                      nodeViewID: node.nodeViews[index],
                      defaultFocus: focusForID(node.nodeViews[index].read(reader)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
