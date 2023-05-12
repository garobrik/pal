import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/table.dart' hide Column;
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'widget.g.dart';

Route<void> generateWidgetRoute(
  Ctx ctx,
  pal.ID widgetID,
) {
  return MaterialPageRoute<void>(
    settings: RouteSettings(
      arguments: model.WidgetRoute(widgetID, ctx: ctx),
    ),
    builder: (_) => ReaderWidget(
      ctx: ctx,
      builder: (context, ctx) {
        late final Cursor<String>? title;
        late final Cursor<Object> instance;
        late final widget.Mode mode;
        if (widgetID is widget.RootID) {
          final root = ctx.db.get(widgetID).whenPresent;
          title = root.recordAccess(widget.rootNameID).cast<String>();
          instance = root.recordAccess(widget.rootInstanceID);
          mode = (root.recordAccess(widget.rootModeID).read(ctx) as Optional<widget.Mode>)
              .orElse(ctx.widgetMode);
        } else if (widgetID is widget.ID) {
          title = null;
          instance = ctx.db.get(widgetID).whenPresent;
          mode = ctx.widgetMode;
        }
        ctx = ctx.withWidgetMode(mode);

        return MainScaffold(
          ctx: ctx,
          body: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Container(
                    padding: const EdgeInsetsDirectional.only(bottom: 20),
                    child: IntrinsicWidth(
                      child: BoundTextFormField(
                        title,
                        ctx: ctx,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                Expanded(
                  child: WidgetRenderer(
                    ctx: ctx,
                    instance: instance,
                  ),
                ),
              ],
            ),
          ),
          replaceRouteOnPush: false,
        );
      },
    ),
  );
}

@reader
Widget _widgetRenderer(
  BuildContext context, {
  required Ctx ctx,
  required GetCursor<Object> instance,
}) {
  final currentName =
      instance.recordAccess(widget.instanceWidgetID).recordAccess(widget.nameID).read(ctx);
  final data = instance.recordAccess(widget.instanceDataID).thenOpt(OptLens<Object, Object>(
        const Vec([]),
        (t) {
          if (currentName ==
              instance
                  .recordAccess(widget.instanceWidgetID)
                  .recordAccess(widget.nameID)
                  .read(Ctx.empty)) {
            return Optional(t);
          } else {
            return const Optional.none();
          }
        },
        (t, f) => f(t),
      ));
  final build =
      instance.recordAccess(widget.instanceWidgetID).recordAccess(widget.buildID).read(ctx);

  final isOpen = useCursor(false);
  final dropdownFocus = useFocusNode();

  return Actions(
    actions: {
      ConfigureNodeViewIntent: CallbackAction<ConfigureNodeViewIntent>(
        onInvoke: (_) {
          if (instance is Cursor<Object>) {
            isOpen.set(true);
          }
          return null;
        },
      ),
    },
    child: Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.keyS, LogicalKeyboardKey.control):
            const ConfigureNodeViewIntent(),
      },
      child: DeferredDropdown(
        dropdownFocus: dropdownFocus,
        isOpen: isOpen,
        childAnchor: Alignment.bottomLeft,
        dropdown: ReaderWidget(
          ctx: ctx,
          builder: (_, ctx) => WidgetConfigWidget(
            ctx: ctx.withDefaultFocus(dropdownFocus),
            instance: instance as Cursor<Object>,
          ),
        ),
        child: build.callFn(ctx, data) as Widget,
      ),
    ),
  );
}

final widgets = [
  tableWidget,
  listWidget,
  textWidget,
  pageWidget,
];

@reader
Widget _widgetConfigWidget({
  required Ctx ctx,
  required Cursor<Object> instance,
}) {
  final thisWidget = instance.recordAccess(widget.instanceWidgetID);

  return IntrinsicWidth(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButtonDropdown(
          childAnchor: Alignment.topRight,
          dropdown: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final widgetDef in widgets)
                  TextButton(
                    onPressed: () {
                      if (thisWidget.read(Ctx.empty) != widgetDef) {
                        instance.set(widget.defaultInstance(ctx, widgetDef));
                      }
                    },
                    child: Row(
                      children: [Text(widgetDef.recordAccess(widget.nameID) as String)],
                    ),
                  ),
              ],
            ),
          ),
          buttonFocus: ctx.defaultFocus,
          child: const Text('View type'),
        ),
      ],
    ),
  );
}
