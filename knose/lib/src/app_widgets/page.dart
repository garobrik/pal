import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'page.g.dart';

final _widgetList = pal.List(
  pal.Union({widget.instanceDef.asType(), widget.idDef.asType()}),
);

final pageWidget = Dict({
  widget.nameID: 'Page',
  widget.fieldsID: Dict<Object, Object>({
    'widgets': _widgetList,
    'title': pal.text,
  }),
  widget.defaultFieldsID: ({required Ctx ctx}) => Dict<Object, Object>({
        'widgets': pal.Value(
          _widgetList,
          Vec([
            pal.Value(
              widget.instanceDef.asType(),
              widget.defaultInstance(ctx, textWidget),
            )
          ]),
        ),
        'title': const pal.Value(pal.text, 'Untitled page'),
      }),
  widget.buildID: PageWidget.new,
});

@reader
Widget _pageWidget(
  BuildContext context,
  Dict<String, Cursor<Object>> fields, {
  required Ctx ctx,
}) {
  final widgetsValue = fields['widgets'].unwrap!;
  final widgets = widgetsValue.cast<Vec<pal.Value>>();
  GetCursor<widget.ID> widgetID(GetCursor<pal.Value> widgetDef) => GetCursor.compute(
        (ctx) {
          if (widgetDef.type.read(ctx).assignableTo(ctx, widget.instanceDef.asType())) {
            return widgetDef.value.recordAccess(widget.instanceIDID).cast<widget.ID>().read(ctx);
          } else {
            return widgetDef.value.cast<widget.ID>().read(ctx);
          }
        },
        ctx: ctx,
      );

  final focusForID = useMemoized(() {
    final foci = <pal.ID, FocusNode>{};
    return (pal.ID id) {
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
                    final instance = pal.Value(
                      widget.instanceDef.asType(),
                      widget.defaultInstance(ctx, textWidget),
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
