import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'list.g.dart';

@immutable
@reify
class ListBuilder extends model.NodeBuilder {
  const ListBuilder();

  @override
  model.NodeBuilderFn get build => ListWidget.tearoff;

  @override
  Dict<String, model.Datum> makeFields(Cursor<model.State> state) {
    return Dict({
      'list': model.Literal<model.List>(
        model.List(
          nodeViews: Vec([const TextBuilder().addView(state)]),
        ),
      )
    });
  }
}

@reader_widget
Widget _listWidget(
  Reader reader,
  BuildContext context, {
  required model.Ctx ctx,
  required Cursor<model.State> state,
  required Dict<String, Cursor<Object>> fields,
  FocusNode? defaultFocus,
}) {
  final list = fields['list'].unwrap!.cast<model.List>();

  final focusForID = useMemoized(() {
    final foci = <model.NodeID<model.NodeView>, FocusNode>{};
    return (model.NodeID<model.NodeView> id) {
      if (list.nodeViews[0].read(reader) == id) {
        return defaultFocus ?? foci.putIfAbsent(id, () => FocusNode());
      }
      return foci.putIfAbsent(id, () => FocusNode());
    };
  });

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final index in range(list.nodeViews.length.read(reader)))
        Padding(
          key: ValueKey(list.nodeViews[index].read(reader)),
          padding: index == 0
              ? const EdgeInsetsDirectional.only(start: 4, end: 4, bottom: 4)
              : const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
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
                          list.nodeViews.insert(
                            index + 1,
                            id = const TextBuilder().addView(state),
                          );
                          focusForID(id).requestFocus();
                        },
                      ),
                      DeleteNodeIntent: CallbackAction<DeleteNodeIntent>(
                        onInvoke: (_) {
                          if (list.nodeViews.length.read(null) > 1) {
                            list.nodeViews.remove(index);
                            focusForID(
                              list.nodeViews[max(index - 1, 0)].read(null),
                            ).requestFocus();
                          } else {
                            Actions.invoke(
                              context,
                              const DeleteNodeIntent(),
                            );
                          }
                        },
                      ),
                    },
                    child: NodeViewWidget(
                      ctx: ctx,
                      state: state,
                      nodeViewID: list.nodeViews[index],
                      defaultFocus:
                          focusForID(list.nodeViews[index].read(reader)),
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
