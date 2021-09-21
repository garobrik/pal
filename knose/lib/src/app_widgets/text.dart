import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'text.g.dart';

class TextBuilder extends model.NodeBuilder {
  const TextBuilder();

  @override
  model.NodeBuilderFn get build => TextWidget.tearoff;

  @override
  Dict<String, model.Datum> makeFields(
      Cursor<model.State> state, model.NodeID<model.NodeView> nodeView) {
    return Dict({
      'text': model.Literal(
        data: const Optional<model.Text>.none(),
        nodeView: nodeView,
        fieldName: 'text',
      )
    });
  }
}

@reader_widget
Widget _textWidget(
  Reader reader,
  BuildContext context, {
  required model.Ctx ctx,
  required Dict<String, Cursor<Object>> fields,
  FocusNode? defaultFocus,
}) {
  final text = fields['text'].unwrap!.cast<Optional<model.Text>>().orElse(model.Text());

  return Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): NewNodeBelowIntent(),
      SingleActivator(LogicalKeyboardKey.backspace, control: true): DeleteNodeIntent(),
    },
    child: BoundTextFormField(
      text.elements[0].cast<model.PlainText>().text,
      maxLines: null,
      focusNode: defaultFocus,
    ),
  );
}
