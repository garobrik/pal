import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'page.g.dart';

final _widgetList = model.ListType(
  model.UnionType({model.widgetInstanceDef.asType(), model.widgetIDDef.asType()}),
);

final pageWidget = Dict({
  model.widgetNameID: 'Page',
  model.widgetFieldsID: Dict<Object, Object>({
    'widgets': _widgetList,
    'title': model.textType,
  }),
  model.widgetDefaultFieldsID: ({required Ctx ctx}) => Dict<Object, Object>({
        'widgets': model.PalValue(
          _widgetList,
          Vec([
            model.PalValue(
              model.widgetInstanceDef.asType(),
              model.defaultInstance(Ctx.empty.withDB(Cursor(model.coreDB)), textWidget),
            )
          ]),
        ),
        'title': const model.PalValue(model.textType, 'Untitled page'),
      }),
  model.widgetBuildID: PageWidget.tearoff,
});

@reader
Widget _pageWidget(
  BuildContext context,
  Dict<String, Cursor<Object>> fields, {
  required Ctx ctx,
}) {
  final widgetsValue = fields['widgets'].unwrap!;
  final widgets = widgetsValue.cast<Vec<model.PalValue>>();
  GetCursor<model.WidgetID> widgetID(GetCursor<model.PalValue> widget) => GetCursor.compute(
        (ctx) {
          if (widget.type.read(ctx).assignableTo(ctx, model.widgetInstanceDef.asType())) {
            return widget.value
                .recordAccess(model.widgetInstanceIDID)
                .cast<model.WidgetID>()
                .read(ctx);
          } else {
            return widget.value.cast<model.WidgetID>().read(ctx);
          }
        },
        ctx: ctx,
      );

  final focusForID = useMemoized(() {
    final foci = <model.PalID, FocusNode>{};
    return (model.PalID id) {
      if (widgetID(widgets[0]).read(ctx) == id) {
        return ctx.defaultFocus ?? foci.putIfAbsent(id, () => FocusNode());
      }
      return foci.putIfAbsent(id, () => FocusNode());
    };
  });

  return TextButton(
    onPressed: () => Actions.maybeInvoke(context, const NewNodeBelowIntent()),
    style: ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith(
        (states) => states.intersection({MaterialState.focused, MaterialState.hovered}).isNotEmpty
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surface,
      ),
      elevation: MaterialStateProperty.resolveWith(
        (states) =>
            states.intersection({MaterialState.focused, MaterialState.hovered}).isNotEmpty ? 2 : 2,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      // onReorder: (old, nu) {
      //   page.nodeViews.atomically((nodeViews) {
      //     nodeViews.insert(nu < old ? nu : nu + 1, nodeViews[old].read(null));
      //     nodeViews.remove(nu < old ? old + 1 : old);
      //   });
      // },
      children: [
        for (final index in range(widgets.length.read(ctx)))
          Padding(
            key: ValueKey(widgetID(widgets[index]).read(ctx)),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Actions(
              actions: {
                NewNodeBelowIntent: NewNodeBelowAction(
                  onInvoke: (_) {
                    final instance = model.PalValue(
                      model.widgetInstanceDef.asType(),
                      model.defaultInstance(ctx, textWidget),
                    );

                    widgets.insert(
                      index + 1,
                      instance,
                    );
                    focusForID(widgetID(GetCursor(instance)).read(Ctx.empty)).requestFocus();
                  },
                ),
                DeleteNodeIntent: CallbackAction<DeleteNodeIntent>(
                  onInvoke: (_) {
                    if (widgets.length.read(Ctx.empty) > 1) {
                      widgets.remove(index);
                    }
                    focusForID(widgetID(widgets[max(index - 1, 0)]).read(Ctx.empty)).requestFocus();
                  },
                ),
              },
              child: WidgetRenderer(
                ctx: ctx.withDefaultFocus(focusForID(widgetID(widgets[index]).read(ctx))),
                instance: widgets[index].value,
              ),
            ),
          ),
      ],
    ),
  );
}
