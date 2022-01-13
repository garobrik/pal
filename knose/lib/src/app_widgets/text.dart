import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'text.g.dart';

final textWidget = widget.def.instantiate({
  widget.nameID: 'Text',
  widget.typeID: pal.Union({
    pal.text,
    pal.optionType(pal.text),
  }),
  widget.defaultDataID: ({required Ctx ctx}) => const pal.Value(pal.text, ''),
  widget.buildID: TextWidget.new,
});

@reader
Widget _textWidget(
  BuildContext context,
  Cursor<Object> text, {
  required Ctx ctx,
}) {
  final stringCursor = Cursor<String>.compute((ctx) {
    final type = text.palType().read(ctx);
    if (type == pal.text) {
      return text.palValue().cast<String>();
    } else if (type.assignableTo(ctx, pal.optionType(pal.text))) {
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
