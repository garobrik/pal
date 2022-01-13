import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'widget.g.dart';

Route generateWidgetRoute(
  Ctx ctx,
  pal.ID widgetID,
) {
  return MaterialPageRoute<void>(
    settings: RouteSettings(
      arguments: model.WidgetRoute(widgetID, ctx: ctx),
    ),
    builder: (_) => MainScaffold(
      ctx: ctx,
      body: WidgetRenderer(
        ctx: ctx,
        instance: ctx.db.get(widgetID).whenPresent,
      ),
      replaceRouteOnPush: false,
    ),
  );
}

@reader
Widget _widgetRenderer(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<Object> instance,
}) {
  final data = instance.recordAccess(widget.instanceDataID);
  final build = instance
      .recordAccess(widget.instanceWidgetID)
      .recordAccess(widget.buildID)
      .read(ctx) as widget.BuildFn;

  final isOpen = useCursor(false);
  final dropdownFocus = useFocusNode();

  return Actions(
    actions: {
      ConfigureNodeViewIntent: CallbackAction<ConfigureNodeViewIntent>(
        onInvoke: (_) => isOpen.set(true),
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
        dropdown: WidgetConfigWidget(
          ctx: ctx.withDefaultFocus(dropdownFocus),
          instance: instance,
        ),
        child: build(data, ctx: ctx),
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
        // for (final fieldName in fields.mapKeys().read(ctx))
        //   ReaderWidget(
        //     ctx: ctx,
        //     builder: (_, ctx) {
        //       return TextButtonDropdown(
        //         dropdown: IntrinsicWidth(
        //           child: Column(
        //             crossAxisAlignment: CrossAxisAlignment.stretch,
        //             children: [
        //               for (final dataSource in ctx.ofType<model.DataSource>())
        //                 for (final datum in dataSource.data.read(ctx))
        //                   if (datum.type(ctx).assignableTo(
        //                         ctx,
        //                         fieldTypes.mapAccess(fieldName).whenPresent.read(ctx) as pal.Type,
        //                       ))
        //                     TextButton(
        //                       onPressed: () => fields
        //                           .mapAccess(fieldName)
        //                           .set(Optional(pal.Value(pal.datumDef.asType(), datum))),
        //                       child: Text(datum.name(ctx)),
        //                     ),
        //             ],
        //           ),
        //         ),
        //         buttonFocus: firstFieldName == fieldName ? ctx.defaultFocus : null,
        //         child: Text('$fieldName: ' //+ fields[fieldName].whenPresent.read(ctx).name(ctx),
        //             ),
        //       );
        //     },
        //   ),
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
