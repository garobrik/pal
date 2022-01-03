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
  final fields = instance.recordAccess(widget.instanceFieldsID);
  final widgetDef = instance.recordAccess(widget.instanceWidgetID);
  final build = widgetDef.recordAccess(widget.buildID).read(ctx) as widget.BuildFn;
  final fieldTypes = widgetDef.recordAccess(widget.fieldsID);

  final evaluatedFields = <String, Cursor<Object>>{};
  final nullFields = <String>[];
  for (final fieldName in fields.mapKeys().read(ctx)) {
    final optCursor = GetCursor.compute((ctx) {
      final field = fields.mapAccess(fieldName).whenPresent;
      final fieldType = fieldTypes.mapAccess(fieldName).whenPresent.read(ctx) as pal.Type;
      if ((field.palType().read(ctx)).assignableTo(ctx, pal.datumDef.asType())) {
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
  final fields = instance.recordAccess(widget.instanceFieldsID);
  final thisWidget = instance.recordAccess(widget.instanceWidgetID);
  final fieldTypes = thisWidget.recordAccess(widget.fieldsID);
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
              return TextButtonDropdown(
                dropdown: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final dataSource in ctx.ofType<model.DataSource>())
                        for (final datum in dataSource.data.read(ctx))
                          if (datum.type(ctx).assignableTo(
                                ctx,
                                fieldTypes.mapAccess(fieldName).whenPresent.read(ctx) as pal.Type,
                              ))
                            TextButton(
                              onPressed: () => fields
                                  .mapAccess(fieldName)
                                  .set(Optional(pal.Value(pal.datumDef.asType(), datum))),
                              child: Text(datum.name(ctx)),
                            ),
                    ],
                  ),
                ),
                buttonFocus: firstFieldName == fieldName ? ctx.defaultFocus : null,
                child: Text('$fieldName: ' //+ fields[fieldName].whenPresent.read(ctx).name(ctx),
                    ),
              );
            },
          ),
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
          buttonFocus: firstFieldName == null ? ctx.defaultFocus : null,
          child: const Text('View type'),
        ),
      ],
    ),
  );
}
