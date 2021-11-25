import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;

part 'widget.g.dart';

Route generateWidgetRoute(
  Ctx ctx,
  model.PalID widgetID,
) {
  return MaterialPageRoute<void>(
    settings: RouteSettings(
      arguments: model.WidgetRoute(widgetID, ctx: ctx),
    ),
    builder: (_) => MainScaffold(
      ctx: ctx,
      body: WidgetRenderer(
        ctx: ctx,
        instance: ctx.db.get(widgetID).whenPresent.cast<model.PalValue>(),
      ),
      replaceRouteOnPush: false,
    ),
  );
}

@reader_widget
Widget _widgetRenderer({
  required Ctx ctx,
  required Cursor<model.PalValue> instance,
}) {
  assert(instance.type.read(ctx).assignableTo(ctx, model.widgetInstanceDef.asType()));
  final fields = instance.recordAccess<Dict<String, model.PalValue>>('fields');
  final widget = instance.recordAccess<model.PalValue>('widget');
  final build = widget.recordAccess<model.WidgetBuildFn>('build').read(ctx);

  final evaluatedFields = <String, Cursor<model.PalValue>>{};
  final nullFields = <String>[];
  for (final fieldName in fields.keys.read(ctx)) {
    if (fields[fieldName].whenPresent.type.read(ctx).assignableTo(ctx, model.datumDef.asType())) {
      final evaluatedField =
          fields[fieldName].whenPresent.value.cast<model.Datum>().read(ctx).build(ctx);
      if (evaluatedField == null) {
        nullFields.add(fieldName);
      } else {
        evaluatedFields[fieldName] = evaluatedField;
      }
    } else {
      evaluatedFields[fieldName] = fields[fieldName].whenPresent.cast<model.PalValue>();
    }
  }

  final isOpen = useCursor(false);
  final dropdownFocus = useFocusNode();

  late final Widget child;
  if (nullFields.isNotEmpty) {
    child = Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => isOpen.set(true),
            child: Text('Fields are null: ${nullFields.join(", ")}.'),
          ),
        ),
      ],
    );
  } else {
    child = build(Dict(evaluatedFields), ctx: ctx);
  }

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
          ctx: ctx,
          instance: instance,
        ),
        child: child,
      ),
    ),
  );
}

final widgets = <model.PalValue>[
  tableWidget,
  listWidget,
  textWidget,
  pageWidget,
];

@reader_widget
Widget _widgetConfigWidget({
  required Ctx ctx,
  required Cursor<model.PalValue> instance,
}) {
  assert(instance.type.read(ctx).assignableTo(ctx, model.widgetInstanceDef.asType()));

  final isOpen = useCursor(false);

  final fields = instance.recordAccess<Dict<String, model.PalValue>>('fields');
  final thisWidget = instance.recordAccess<model.PalValue>('widget');
  final fieldTypes = thisWidget.recordAccess<Dict<String, model.PalType>>('fields');

  return IntrinsicWidth(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final fieldName in fields.keys.read(ctx))
          ReaderWidget(
            ctx: ctx,
            builder: (_, ctx) {
              final fieldIsOpen = useCursor(false);
              return DeferredDropdown(
                isOpen: fieldIsOpen,
                dropdown: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final dataSource in ctx.ofType<model.DataSource>())
                        for (final datum in dataSource.data.read(ctx))
                          if (datum
                              .type(ctx)
                              .assignableTo(ctx, fieldTypes[fieldName].whenPresent.read(ctx)))
                            TextButton(
                              onPressed: () => fields[fieldName] = Optional(model.PalValue(model.datumDef.asType(), datum)),
                              child: Text(datum.name(ctx)),
                            ),
                    ],
                  ),
                ),
                child: TextButton(
                  onPressed: () => fieldIsOpen.set(!fieldIsOpen.read(Ctx.empty)),
                  child: Text(
                    '$fieldName: ' //+ fields[fieldName].whenPresent.read(ctx).name(ctx),
                  ),
                ),
              );
            },
          ),
        DeferredDropdown(
          isOpen: isOpen,
          childAnchor: Alignment.topRight,
          dropdown: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final widget in widgets)
                  TextButton(
                    onPressed: () {
                      if (thisWidget.read(Ctx.empty) != widget) {
                        instance.set(model.defaultInstance(ctx, widget));
                      }
                    },
                    child: Row(children: [Text(widget.recordAccess<String>('name'))]),
                  ),
              ],
            ),
          ),
          child: TextButton(
            onPressed: () => isOpen.set(!isOpen.read(Ctx.empty)),
            child: const Text('View type'),
          ),
        ),
      ],
    ),
  );
}
