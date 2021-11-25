import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'text.g.dart';

final textWidget = model.PalValue(
  model.widgetDef.asType(),
  Dict({
    'name': 'Text',
    'fields': Dict({
      'text': model.UnionType({
        model.textType,
        model.richTextDef.asType(),
        textOption,
      }),
    }),
    'defaultFields': ({required Ctx ctx}) =>
        const Dict({'text': model.PalValue(model.textType, '')}),
    'build': TextWidget.tearoff,
  }),
);

final textOption = model.optionDef.asType({model.optionMemberID: model.textType});

@reader_widget
Widget _textWidget(
  BuildContext context,
  Dict<String, Cursor<model.PalValue>> fields, {
  required Ctx ctx,
}) {
  final text = fields['text'].unwrap!;
  final type = text.type.read(ctx);
  late final Cursor<String> stringCursor;
  if (type == model.textType) {
    stringCursor = text.value.cast<String>();
  } else if (type.assignableTo(ctx, textOption)) {
    stringCursor = text.value
        .cast<Optional<model.PalValue>>()
        .orElse(const model.PalValue(model.textType, ''))
        .value
        .cast<String>(); // text.cast<model.Text>().elements[0].cast<model.PlainText>().text;
  } else {
    print(type);
  }

  return Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): NewNodeBelowIntent(),
      SingleActivator(LogicalKeyboardKey.backspace, control: true): DeleteNodeIntent(),
    },
    child: BoundTextFormField(
      stringCursor,
      ctx: ctx,
      maxLines: null,
      focusNode: ctx.defaultFocus,
    ),
  );
}
