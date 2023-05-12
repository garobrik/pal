import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:infra_widgets/inline_spans.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

part 'text.g.dart';

final textWidget = widget.def.instantiate({
  widget.nameID: 'Text',
  widget.typeID: widget.datumOr(pal.Union({pal.text, pal.optionType(pal.text)})),
  widget.defaultDataID: (Ctx ctx, Object _) => widget.datumOr.instantiate(
        type: pal.Union({pal.text, pal.optionType(pal.text)}),
        data: const pal.Value(pal.text, ''),
      ),
  widget.buildID: TextWidget.new,
});

@reader
Widget _textWidget(BuildContext context, Ctx ctx, Object datumOrText) {
  final text = widget.evalDatumOr(ctx, datumOrText as Cursor<Object>);

  late final Widget child;
  if (ctx.widgetMode == widget.Mode.edit) {
    child = Text.rich(TextSpan(children: [
      const TextSpan(text: 'TextWidget(value: '),
      AlignedWidgetSpan(widget.EditDatumOr(ctx: ctx, datumOr: datumOrText)),
      const TextSpan(text: ')'),
    ]));
  } else if (text != null) {
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

    child = BoundTextFormField(
      stringCursor,
      ctx: ctx,
      maxLines: null,
      focusNode: ctx.defaultFocus,
    );
  } else {
    return const Text('Error: text datum is not buildable or has wrong type.');
  }

  return Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): NewNodeBelowIntent(),
      SingleActivator(LogicalKeyboardKey.backspace, control: true): DeleteNodeIntent(),
    },
    child: child,
  );
}
