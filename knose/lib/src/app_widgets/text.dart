import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'text.g.dart';

class TextBuilder with model.TypedNodeBuilder<model.Text> {
  const TextBuilder();

  @override
  model.NodeBuilderFn<model.Text> get buildTyped => TextWidget.tearoff;
}

extension AddTextView on Cursor<model.State> {
  model.NodeID<model.NodeView<model.Text>> addTextView() {
    return addNode(
      model.NodeView.from(
        builder: const TextBuilder(),
        nodeID: addNode(model.Text()),
      ),
    );
  }
}

@reader_widget
Widget _textWidget(
  Reader reader,
  Cursor<model.State> state,
  Cursor<model.Text> text,
) {
  return Shortcuts(
    shortcuts: {
      SingleActivator(LogicalKeyboardKey.enter): NewNodeBelowIntent(),
    },
    child: BoundTextFormField(
      text.elements[0].cast<model.PlainText>().text,
      maxLines: null,
    ),
  );
}
