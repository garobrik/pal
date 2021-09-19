import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'page.g.dart';

@immutable
@reify
class PageBuilder extends model.TopLevelNodeBuilder {
  const PageBuilder();

  @override
  model.NodeBuilderFn get build => PageWidget.tearoff;

  @override
  Dict<String, model.Datum> makeFields(
    Cursor<model.State> state,
    model.NodeID<model.NodeView> nodeView,
  ) {
    return Dict({
      'page': model.Literal(
        data: Optional(
          model.Page(
            title: 'Untitled page',
            nodeViews: Vec([
              const TextBuilder().addView(state),
            ]),
          ),
        ),
        nodeView: nodeView,
        fieldName: 'page',
      )
    });
  }

  @override
  Cursor<String> title({
    required model.Ctx ctx,
    required Dict<String, Cursor<Optional<Object>>> fields,
  }) {
    return fields['page'].unwrap!.cast<Optional<model.Page>>().whenPresent.title;
  }
}

@reader_widget
Widget _pageWidget(
  Reader reader,
  BuildContext context, {
  required model.Ctx ctx,
  required Dict<String, Cursor<Object>> fields,
  FocusNode? defaultFocus,
}) {
  final page = fields['page'].unwrap!.cast<Optional<model.Page>>().whenPresent;

  final focusForID = useMemoized(() {
    final foci = <model.NodeID<model.NodeView>, FocusNode>{};
    return (model.NodeID<model.NodeView> id) {
      if (page.nodeViews[0].read(reader) == id) {
        return defaultFocus ?? foci.putIfAbsent(id, () => FocusNode());
      }
      return foci.putIfAbsent(id, () => FocusNode());
    };
  });

  return Container(
    color: Theme.of(context).colorScheme.background,
    // constraints: const BoxConstraints.expand(),
    child: Container(
      // margin: EdgeInsets.all(15),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black38)],
      ),
      child: Column(
        // onReorder: (old, nu) {
        //   page.nodeViews.atomically((nodeViews) {
        //     nodeViews.insert(nu < old ? nu : nu + 1, nodeViews[old].read(null));
        //     nodeViews.remove(nu < old ? old + 1 : old);
        //   });
        // },
        children: [
          for (final index in range(page.nodeViews.length.read(reader)))
            Padding(
              key: ValueKey(page.nodeViews[index].read(reader)),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                elevation: 6,
                child: Actions(
                  actions: {
                    NewNodeBelowIntent: NewNodeBelowAction(
                      onInvoke: (_) {
                        late final model.NodeID<model.NodeView> id;
                        page.nodeViews.insert(
                          index + 1,
                          id = const TextBuilder().addView(ctx.state),
                        );
                        focusForID(id).requestFocus();
                      },
                    ),
                    DeleteNodeIntent: CallbackAction<DeleteNodeIntent>(
                      onInvoke: (_) {
                        if (page.nodeViews.length.read(null) > 1) {
                          page.nodeViews.remove(index);
                        }
                        focusForID(page.nodeViews[max(index - 1, 0)].read(null))
                            .requestFocus();
                      },
                    ),
                  },
                  child: NodeViewWidget(
                    ctx: ctx,
                    nodeViewID: page.nodeViews[index],
                    defaultFocus:
                        focusForID(page.nodeViews[index].read(reader)),
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
Widget _pageHeader(
    Reader reader, BuildContext context, Cursor<model.Header> header) {
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
