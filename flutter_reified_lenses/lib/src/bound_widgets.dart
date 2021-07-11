import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'bound_widgets.g.dart';

@reader_widget
Widget _boundTextFormField(
  BuildContext context,
  Reader reader,
  Cursor<String> text, {
  int? maxLines = 1,
  TextInputType? keyboardType,
  InputDecoration decoration = const InputDecoration(),
  TextStyle? style,
  TextAlignVertical? textAlignVertical,
  bool autofocus = false,
  FocusNode? focusNode,
  bool readOnly = false,
  bool expands = false,
}) {
  focusNode ??= useFocusNode(skipTraversal: readOnly);
  final textController = useTextEditingController(text: text.read(reader));

  useEffect(() {
    return text.listen((_, __, Diff diff) {
      if (!focusNode!.hasFocus) {
        textController.text = text.read(reader);
      }
    });
  }, [textController, text, focusNode]);

  return TextFormField(
    maxLines: maxLines,
    controller: textController,
    keyboardType: keyboardType,
    decoration: decoration,
    style: style,
    textAlignVertical: textAlignVertical,
    autofocus: autofocus,
    focusNode: focusNode,
    readOnly: readOnly,
    onChanged: (newText) => text.set(newText),
    expands: expands,
    scrollPadding: ,
  );
}
