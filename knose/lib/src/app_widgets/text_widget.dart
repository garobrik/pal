import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;

part 'text_widget.g.dart';

class TextBuilder with model.TypedNodeBuilder<model.Text> {
  const TextBuilder();

  @override
  model.NodeBuilderFn<model.Text> get typedBuilder => TextWidget.tearoff;
}

@reader_widget
Widget _textWidget(
  Reader reader,
  Cursor<model.State> state,
  Cursor<model.Text> text,
) {
  return BoundTextFormField(
    text.elements[0].cast<model.PlainText>().text,
    maxLines: null,
  );
}
