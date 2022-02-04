import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'page.g.dart';

final pageModeID = pal.MemberID();
final pageLiteralID = pal.MemberID();
final pageComputedID = pal.MemberID();
final pageComputedTypeID = pal.MemberID();
final pageComputedDataID = pal.MemberID();
final pageComputedFnID = pal.MemberID();
final pageTitleID = pal.MemberID();
final pageDataDef = pal.DataDef(
  tree: pal.RecordNode('PageData', {
    pageModeID: pal.UnionNode('mode', {
      pageLiteralID: pal.LeafNode('literal', pal.List(widget.instance)),
      pageComputedID: pal.RecordNode('computed', {
        pageComputedTypeID: const pal.LeafNode('type', pal.type),
        pageComputedDataID: pal.LeafNode(
          'data',
          pal.List(
            pal.RecordAccess(
              pageComputedTypeID,
              target: pal.UnionAccess(pageComputedID, target: pal.RecordAccess(pageModeID)),
            ),
          ),
        ),
        pageComputedFnID: pal.LeafNode(
          'fn',
          pal.FunctionType(
            returnType: widget.instance,
            target: pal.cursorType(
              pal.RecordAccess(
                pageComputedTypeID,
                target: pal.UnionAccess(pageComputedID, target: pal.RecordAccess(pageModeID)),
              ),
            ),
          ),
        )
      }),
    }),
    pageTitleID: const pal.LeafNode('title', pal.text),
  }),
);

final pageWidget = widget.def.instantiate({
  widget.nameID: 'Page',
  widget.typeID: pageDataDef.asType(),
  widget.defaultDataID: ({required Ctx ctx}) => pageDataDef.instantiate({
        pageModeID: pal.UnionTag(pageLiteralID, Vec([widget.defaultInstance(ctx, textWidget)])),
        pageTitleID: 'Untitled page',
      }),
  widget.buildID: PageWidget.new,
});

@reader
Widget _pageWidget(
  BuildContext context,
  Cursor<Object> data, {
  required Ctx ctx,
}) {
  final widgets = data.recordAccess(pageModeID).dataCases(ctx, {
    pageLiteralID: (obj) => obj.cast<Vec<Object>>(),
  });
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
                    final instance = widget.defaultInstance(ctx, textWidget);

                    widgets.insert(
                      index + 1,
                      instance,
                    );
                    focusForID(widgetID(GetCursor(instance)).read(Ctx.empty)).requestFocus();

                    return null;
                  },
                ),
                DeleteNodeIntent: CallbackAction<DeleteNodeIntent>(
                  onInvoke: (_) {
                    if (widgets.length.read(Ctx.empty) > 1) {
                      widgets.remove(index);
                    }
                    focusForID(widgetID(widgets[max(index - 1, 0)]).read(Ctx.empty)).requestFocus();

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
  );
}
