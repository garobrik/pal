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
    Cursor<model.State> state,
    model.NodeID<model.NodeView> nodeView,
  ) {
    return Dict({
      'text': model.Literal(
        // TODO: fix type
        typeData: model.UnionType({model.plainTextType, model.booleanType}),
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
  final text = fields['text'].unwrap!;
  final type = text.type(reader);
  late final Cursor<String> stringCursor;
  if (type == String) {
    stringCursor = text.cast<String>();
  } else {
    stringCursor = text
        .cast<Optional<model.Text>>()
        .orElse(model.Text())
        .elements[0]
        .cast<model.PlainText>()
        .text;
  }

  return Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): NewNodeBelowIntent(),
      SingleActivator(LogicalKeyboardKey.backspace, control: true): DeleteNodeIntent(),
    },
    child: BoundTextFormField(
      stringCursor,
      maxLines: null,
      focusNode: defaultFocus,
    ),
  );
}
