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
  BuildContext context,
  Cursor<model.State> state,
  Cursor<model.List> list,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final index in range(list.nodeViews.length.read(reader)))
        Padding(
          key: ValueKey(list.nodeViews[index].read(reader)),
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
                          list.nodeViews.insert(
                            index + 1,
                            state.addTextView(),
                          );
                        },
                      ),
                    },
                    child: NodeViewWidget(
                      state,
                      list.nodeViews[index],
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
