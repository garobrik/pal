import 'package:ctx/ctx.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'bound_widgets.g.dart';

@reader_widget
Widget _boundTextFormField(
  BuildContext context,
  Cursor<String> text, {
  required Ctx ctx,
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
  focusNode = useMemoized(
    () => focusNode == null
        ? FocusNode(skipTraversal: readOnly)
        : (focusNode..skipTraversal = readOnly),
    [focusNode, readOnly],
  );
  final textController = useTextEditingController(text: text.read(Ctx.empty));

  useEffect(() {
    return text.listen((_, __, Diff diff) {
      if (!focusNode!.hasFocus && diff.isNotEmpty) {
        textController.text = text.read(Ctx.empty);
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
    onChanged: text.set,
    expands: expands,
  );
}
