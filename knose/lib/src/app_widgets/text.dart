import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'text.g.dart';

final textWidget = Dict({
  widget.nameID: 'Text',
  widget.fieldsID: Dict({
    'text': pal.Union({
      pal.text,
      textOption,
    }),
  }),
  widget.defaultFieldsID: ({required Ctx ctx}) =>
      const Dict<Object, Object>({'text': pal.Value(pal.text, '')}),
  widget.buildID: TextWidget.new,
});

final textOption = pal.optionType(pal.text);

@reader
Widget _textWidget(
  BuildContext context,
  Dict<String, Cursor<Object>> fields, {
  required Ctx ctx,
}) {
  final text = fields['text'].unwrap!;
  final stringCursor = Cursor<String>.compute((ctx) {
    final type = text.palType().read(ctx);
    if (type == pal.text) {
      return text.palValue().cast<String>();
    } else if (type.assignableTo(ctx, textOption)) {
      return text
          .palValue()
          .cast<Optional<Object>>()
          .optionalCast<String>()
          .orElse(''); // text.cast<model.Text>().elements[0].cast<model.PlainText>().text;
    } else {
      return Cursor('whoops');
    }
  }, ctx: ctx);

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
