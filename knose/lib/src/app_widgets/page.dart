import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide DropdownMenu;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infra_widgets/inline_spans.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;
import 'package:knose/model.dart' as model;

part 'page.g.dart';

final pageModeID = pal.MemberID();
final pageLiteralID = pal.MemberID();
final pageComputedID = pal.MemberID();
final pageComputedTypeID = pal.MemberID();
final pageComputedDefaultID = pal.MemberID();
final pageComputedDataID = pal.MemberID();
final pageComputedWidgetID = pal.MemberID();
final pageDataDef = pal.DataDef(
  tree: pal.RecordNode('PageData', {
    pageModeID: pal.UnionNode('mode', {
      pageLiteralID: pal.LeafNode('literal', pal.List(widget.instance)),
      pageComputedID: pal.RecordNode('computed', {
        pageComputedTypeID: const pal.LeafNode('type', pal.type),
        pageComputedDefaultID: pal.LeafNode('default', pal.RecordAccess(pageComputedTypeID)),
        pageComputedDataID: pal.LeafNode(
          'data',
          widget.datumOr(
            pal.List(
              pal.RecordAccess(
                pageComputedTypeID,
                target: pal.UnionAccess(pageComputedID, pal.RecordAccess(pageModeID)),
              ),
            ),
          ),
        ),
        pageComputedWidgetID: pal.LeafNode('widget', widget.instance)
      }),
    }),
  }),
);

final pageWidget = widget.def.instantiate({
  widget.nameID: 'Page',
  widget.typeID: pageDataDef.asType(),
  widget.defaultDataID: (Ctx ctx, Object _) => pageDataDef.instantiate({
        pageModeID: pal.UnionTag(pageLiteralID, Vec([widget.defaultInstance(ctx, textWidget)])),
      }),
  widget.buildID: PageWidget.new,
});

@reader
Widget _pageWidget(BuildContext context, Ctx ctx, Object data) {
  return (data as Cursor<Object>).recordAccess(pageModeID).dataCases(ctx, {
    pageLiteralID: (unionValue) {
      final widgets = unionValue.cast<Vec<Object>>();

      final pageChildren = PageChildren(
        ctx,
        widgets: widgets,
        keyOf: (ctx, index) => widgets[index].recordAccess(widget.instanceIDID).read(ctx),
        insert: (ctx, index) {
          final instance = widget.defaultInstance(ctx, textWidget);
          widgets.insert(index, instance);
          return instance.recordAccess(widget.instanceIDID);
        },
        remove: (index) => widgets.remove(index),
      );

      if (ctx.widgetMode == widget.Mode.view) return pageChildren;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Page(mode: '),
            AlignedWidgetSpan(ModeDropdown(ctx, data)),
            const TextSpan(text: ', children:'),
          ])),
          Container(
            padding: const EdgeInsetsDirectional.only(top: 5, bottom: 5, start: 10),
            child: pageChildren,
          ),
          const Text(')'),
        ],
      );
    },
    pageComputedID: (computed) {
      final type = computed.recordAccess(pageComputedTypeID).cast<pal.Type>();
      final computedWidget = computed.recordAccess(pageComputedWidgetID);
      final mode = ctx.widgetMode;

      if (mode == widget.Mode.view) {
        final computedData =
            widget.evalDatumOr(ctx, computed.recordAccess(pageComputedDataID))!.cast<Vec<Object>>();

        return PageChildren(
          ctx,
          widgets: GetCursor.compute(
            (ctx) {
              final length = computedData.length.read(ctx);
              return Vec([
                for (final index in range(length))
                  widget.functional(
                    ctx,
                    (ctx) => WidgetRenderer(
                      ctx: ctx.withElement(_ListElemSource(type.read(ctx), computedData[index])),
                      instance: computedWidget,
                    ),
                  ),
              ]);
            },
            ctx: ctx,
          ),
          keyOf: (ctx, index) => index,
          insert: (ctx, index) {
            computedData.insert(
                index, computed.recordAccess(pageComputedDefaultID).read(Ctx.empty));
            return index;
          },
          remove: (index) => computedData.remove(index),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Page('),
          Container(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('mode: '),
                    ModeDropdown(ctx, data),
                    const Text(','),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('data: '),
                    widget.EditDatumOr(
                      ctx: ctx,
                      datumOr: computed.recordAccess(pageComputedDataID),
                    ),
                    const Text(','),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('computed child: '),
                    WidgetRenderer(
                      ctx: ctx.withElement(_ListElemSource(type.read(ctx))),
                      instance: computedWidget,
                    ),
                    const Text(','),
                  ],
                ),
              ],
            ),
          ),
          const Text(')'),
        ],
      );
    },
  });
}

@reader
Widget _modeDropdown(Ctx ctx, Cursor<Object> data) {
  final currentMode = data.recordAccess(pageModeID).dataCase.read(ctx);
  return DropdownMenu(
    items: [pageLiteralID, pageComputedID],
    currentItem: currentMode,
    style: ButtonStyle(
      padding: MaterialStateProperty.all(
        const EdgeInsetsDirectional.only(start: 0, end: 0),
      ),
    ),
    buildItem: (pal.MemberID pageMode) => Text(pageDataDef.memberName(pageMode)),
    onItemSelected: (pal.MemberID mode) {
      if (mode == currentMode) {
        return;
      } else if (mode == pageLiteralID) {
        data.recordAccess(pageModeID).set(pal.UnionTag(
              pageLiteralID,
              Vec([widget.defaultInstance(ctx, textWidget)]),
            ));
      } else if (mode == pageComputedID) {
        final defaultTextWidget = Cursor(widget.defaultInstance(ctx, textWidget));

        widget.setDatumOrDatum(
          ctx: ctx,
          datumOr: defaultTextWidget.recordAccess(widget.instanceDataID),
          newDatum: const _ListElemDatum(),
        );

        data.recordAccess(pageModeID).set(pal.UnionTag(
              pageComputedID,
              Dict({
                pageComputedTypeID: pal.text,
                pageComputedDefaultID: '',
                pageComputedDataID: widget.datumOr
                    .instantiate(type: const pal.List(pal.text), data: const Vec([''])),
                pageComputedWidgetID: defaultTextWidget.read(Ctx.empty),
              }),
            ));
      }
    },
    child: Text(pageDataDef.memberName(currentMode)),
  );
}

@reader
Widget _pageChildren(
  BuildContext context,
  Ctx ctx, {
  required GetCursor<Vec<Object>> widgets,
  required Object Function(Ctx ctx, int index) keyOf,
  required Object Function(Ctx ctx, int index) insert,
  required void Function(int index) remove,
}) {
  final focusForID = useMemoized(() {
    final foci = <Object, FocusNode>{};
    return (Object id) {
      if (keyOf(ctx, 0) == id) {
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
      mainAxisAlignment: MainAxisAlignment.start,
      // onReorder: (old, nu) {
      //   page.nodeViews.atomically((nodeViews) {
      //     nodeViews.insert(nu < old ? nu : nu + 1, nodeViews[old].read(null));
      //     nodeViews.remove(nu < old ? old + 1 : old);
      //   });
      // },
      children: [
        for (final index in range(widgets.length.read(ctx)))
          Padding(
            key: ValueKey(keyOf(ctx, index)),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Actions(
              actions: {
                NewNodeBelowIntent: NewNodeBelowAction(
                  onInvoke: (_) {
                    focusForID(insert(ctx, index + 1)).requestFocus();
                    return null;
                  },
                ),
                DeleteNodeIntent: CallbackAction<DeleteNodeIntent>(
                  onInvoke: (_) {
                    if (widgets.length.read(Ctx.empty) > 1) {
                      remove(index);
                    }
                    focusForID(keyOf(Ctx.empty, max(index - 1, 0))).requestFocus();

                    return null;
                  },
                ),
              },
              child: WidgetRenderer(
                ctx: ctx.withDefaultFocus(focusForID(keyOf(ctx, index))),
                instance: widgets[index],
              ),
            ),
          ),
      ],
    ),
  );
}

class _ListElemSource extends model.DataSource {
  final pal.Type type;
  final Cursor<Object>? value;

  _ListElemSource(this.type, [this.value]);

  @override
  GetCursor<Vec<model.Datum>> get data => const GetCursor(Vec([_ListElemDatum()]));
}

class _ListElemDatum extends model.Datum {
  const _ListElemDatum();

  @override
  String name(Ctx ctx) => 'List Element';

  @override
  pal.Type type(Ctx ctx) => ctx.get<_ListElemSource>()!.type;

  @override
  Cursor<Object>? value(Ctx ctx) => ctx.get<_ListElemSource>()!.value;
}
