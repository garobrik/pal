import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'page.g.dart';

@immutable
@reify
class PageBuilder with model.TypedNodeBuilder<model.Page> {
  const PageBuilder();

  @override
  model.NodeBuilderFn<model.Page> get buildTyped => PageWidget.tearoff;
}

@reader_widget
Widget _pageWidget(
  Reader reader,
  BuildContext context, {
  required Cursor<model.State> state,
  required Cursor<model.Page> node,
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

  return Container(
    color: Theme.of(context).colorScheme.background,
    constraints: BoxConstraints.expand(),
    child: Container(
      // margin: EdgeInsets.all(15),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black38)],
      ),
      child: Column(
        // onReorder: (old, nu) {
        //   page.nodeViews.atomically((nodeViews) {
        //     nodeViews.insert(nu < old ? nu : nu + 1, nodeViews[old].read(null));
        //     nodeViews.remove(nu < old ? old + 1 : old);
        //   });
        // },
        children: [
          for (final index in range(node.nodeViews.length.read(reader)))
            Padding(
              key: ValueKey(node.nodeViews[index].read(reader)),
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Material(
                elevation: 6,
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
                        if (node.nodeViews.length.read(null) > 1) node.nodeViews.remove(index);
                        focusForID(node.nodeViews[max(index - 1, 0)].read(null)).requestFocus();
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
  );
}

@reader_widget
Widget _pageHeader(Reader reader, BuildContext context, Cursor<model.Header> header) {
  final textTheme = Theme.of(context).textTheme;

  return BoundTextFormField(
    header.text,
    style: () {
      switch (header.level.read(reader)) {
        case 1:
          return textTheme.headline1!;
        case 2:
          return textTheme.headline2!;
        case 3:
          return textTheme.headline3!;
        default:
          return textTheme.headline4!;
      }
    }()
        .copyWith(decoration: TextDecoration.underline),
  );
}
