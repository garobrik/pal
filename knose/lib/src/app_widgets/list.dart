import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'list.g.dart';

final _widgetList = model.ListType(
  model.UnionType({model.widgetInstanceDef.asType(), model.widgetIDDef.asType()}),
);

final listWidget = Dict({
  model.widgetNameID: 'Bullet List',
  model.widgetFieldsID: Dict({
    'widgets': _widgetList,
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
      }),
  model.widgetBuildID: ListWidget.tearoff,
});

@reader
Widget _listWidget(
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
                          final instance = model.PalValue(
                            model.widgetInstanceDef.asType(),
                            model.defaultInstance(ctx, textWidget),
                          );
                          widgets.insert(
                            index + 1,
                            instance,
                          );
                          focusForID(widgetID(Cursor(instance)).read(Ctx.empty)).requestFocus();
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
          ),
      ],
    ),
  );
}
