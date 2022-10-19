import 'package:ctx/ctx.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter/material.dart';

part 'bound_widgets.g.dart';

@reader
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
  bool expands = false,
}) {
  focusNode = useMemoized(
    () => focusNode ?? FocusNode(),
    [focusNode],
  );
  final textController = useMemoized(
    () {
      return TextEditingController.fromValue(
        TextEditingValue(
          text: text.read(Ctx.empty),
          selection: TextSelection.collapsed(offset: focusNode!.hasPrimaryFocus ? 0 : -1),
        ),
      );
    },
    [text],
  );

  useEffect(() {
    return text.listen((_, nu, diff) {
      if (!focusNode!.hasFocus && diff.isNotEmpty) {
        textController.text = nu;
      }
    });
  }, [textController, text, focusNode]);

  useEffect(() {
    if (focusNode!.hasPrimaryFocus) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) {
          focusNode?.context?.findAncestorStateOfType<EditableTextState>()?.requestKeyboard();
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          focusNode?.notifyListeners();
        },
      );
    }
    return null;
  }, []);

  return TextFormField(
    maxLines: maxLines,
    controller: textController,
    keyboardType: keyboardType,
    decoration: decoration,
    style: style,
    textAlignVertical: textAlignVertical,
    autofocus: autofocus,
    focusNode: focusNode,
    onChanged: text.set,
    expands: expands,
  );
}
