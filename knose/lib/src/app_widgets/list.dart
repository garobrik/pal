import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'list.g.dart';

final listWidget = widget.def.instantiate({
  widget.nameID: 'List',
  widget.typeID: pal.List(widget.instance),
  widget.defaultDataID: (Ctx ctx, Object _) => Vec([widget.defaultInstance(ctx, textWidget)]),
  widget.buildID: ListWidget.new,
});

@reader
Widget _listWidget(BuildContext context, Ctx ctx, Object list) {
  final widgets = (list as Cursor<Object>).cast<Vec<Object>>();

  GetCursor<widget.ID> widgetID(GetCursor<Object> widgetDef) => GetCursor.compute(
        (ctx) => widgetDef.recordAccess(widget.instanceIDID).cast<widget.ID>().read(ctx),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final index in range(widgets.length.read(ctx)))
          Padding(
            key: ValueKey(widgetID(widgets[index]).read(ctx)),
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
                  child: Actions(
                    actions: {
                      NewNodeBelowIntent: NewNodeBelowAction(
                        onInvoke: (_) {
                          final instance = widget.defaultInstance(ctx, textWidget);
                          widgets.insert(index + 1, instance);
                          focusForID(widgetID(Cursor(instance)).read(Ctx.empty)).requestFocus();
                          return null;
                        },
                      ),
                      DeleteNodeIntent: CallbackAction<DeleteNodeIntent>(
                        onInvoke: (_) {
                          if (widgets.length.read(Ctx.empty) > 1) {
                            widgets.remove(index);
                            focusForID(widgetID(widgets[max(index - 1, 0)]).read(Ctx.empty))
                                .requestFocus();
                          } else {
                            Actions.invoke(
                              context,
                              const DeleteNodeIntent(),
                            );
                          }
                          return null;
                        },
                      ),
                    },
                    child: WidgetRenderer(
                      ctx: ctx.withDefaultFocus(focusForID(widgetID(widgets[index]).read(ctx))),
                      instance: widgets[index],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
