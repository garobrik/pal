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
  final fields = instance.recordAccess(model.widgetInstanceFieldsID);
  final widget = instance.recordAccess(model.widgetInstanceWidgetID);
  final build = widget.recordAccess(model.widgetBuildID).read(ctx) as model.WidgetBuildFn;
  final fieldTypes = widget.recordAccess(model.widgetFieldsID);

  final evaluatedFields = <String, Cursor<Object>>{};
  final nullFields = <String>[];
  for (final fieldName in fields.mapKeys().read(ctx)) {
    final optCursor = GetCursor.compute((ctx) {
      final field = fields.mapAccess(fieldName).whenPresent;
      final fieldType = fieldTypes.mapAccess(fieldName).whenPresent.read(ctx) as model.PalType;
      if ((field.palType().read(ctx)).assignableTo(ctx, model.datumDef.asType())) {
        final datum = field.palValue().cast<model.Datum>().read(ctx);
        final evaluatedField = datum.build(ctx);
        final evaluatedType = datum.type(ctx);
        if (!fieldType.isConcrete && evaluatedType.isConcrete) {
          return evaluatedField == null
              ? const Optional<Cursor<Object>>.none()
              : Optional(evaluatedField.wrap(evaluatedType).upcast<Object>());
        } else {
          return Optional.fromNullable(evaluatedField);
        }
      } else {
        if (fieldType.isConcrete) {
          return Optional(field.palValue());
        } else {
          return Optional(field);
        }
      }
    }, ctx: ctx);
    if (optCursor.isPresent.read(ctx)) {
      evaluatedFields[fieldName as String] = optCursor.whenPresent.flatten;
    } else {
      nullFields.add(fieldName as String);
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
            onPressed: () => Actions.invoke(context, const NewNodeBelowIntent()),
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
          ctx: ctx.withDefaultFocus(dropdownFocus),
          instance: instance,
        ),
        child: child,
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
  final isOpen = useCursor(false);

  final fields = instance.recordAccess(model.widgetInstanceFieldsID);
  final thisWidget = instance.recordAccess(model.widgetInstanceWidgetID);
  final fieldTypes = thisWidget.recordAccess(model.widgetFieldsID);
  final firstFieldName =
      fields.mapKeys().read(ctx).isNotEmpty ? fields.mapKeys().read(ctx).first : null;

  return IntrinsicWidth(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final fieldName in fields.mapKeys().read(ctx))
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
                          if (datum.type(ctx).assignableTo(
                                ctx,
                                fieldTypes.mapAccess(fieldName).whenPresent.read(ctx)
                                    as model.PalType,
                              ))
                            TextButton(
                              onPressed: () => fields
                                  .mapAccess(fieldName)
                                  .set(Optional(model.PalValue(model.datumDef.asType(), datum))),
                              child: Text(datum.name(ctx)),
                            ),
                    ],
                  ),
                ),
                child: TextButton(
                  focusNode: firstFieldName == fieldName ? ctx.defaultFocus : null,
                  onPressed: () => fieldIsOpen.set(!fieldIsOpen.read(Ctx.empty)),
                  child: Text('$fieldName: ' //+ fields[fieldName].whenPresent.read(ctx).name(ctx),
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
                    child: Row(
                      children: [Text(widget.recordAccess(model.widgetNameID) as String)],
                    ),
                  ),
              ],
            ),
          ),
          child: TextButton(
            focusNode: firstFieldName == null ? ctx.defaultFocus : null,
            onPressed: () => isOpen.set(!isOpen.read(Ctx.empty)),
            child: const Text('View type'),
          ),
        ),
      ],
    ),
  );
}
