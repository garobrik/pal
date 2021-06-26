import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

part 'primitives.g.dart';

@reader_widget
Widget _boundTextField(
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
}) {
  final textController = useTextEditingController(text: text.read(reader));
  final firstFrame = useState(true);
  if (firstFrame.value) {
    scheduleMicrotask(() => firstFrame.value = false);
  }
  // useEffect(() {
  //   return text.listen(() => textController.text = text.get);
  // }, [textController, text]);

  return Form(
    child: Builder(
      builder: (context) => Focus(
        skipTraversal: true,
        onKey: (focus, keyEvent) {
          if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
            focus.unfocus();
            return KeyEventResult.handled;
          } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
            if (!keyEvent.isShiftPressed) {
              focus.nextFocus();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextFormField(
          maxLines: maxLines,
          controller: textController,
          keyboardType: keyboardType,
          decoration: decoration,
          style: style,
          textAlignVertical: textAlignVertical,
          autofocus: autofocus,
          focusNode: focusNode,
          onChanged: (newText) => text.set(newText),
        ),
      ),
    ),
  );
}

@reader_widget
Widget _dropdown({
  required Widget child,
  required Widget dropdown,
  Alignment? childAnchor,
  Alignment? dropdownAnchor,
  ButtonStyle? style,
  double? width,
}) {
  final isOpen = useState(false);
  final focusNode = useFocusNode();

  return FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: PortalEntry(
      visible: isOpen.value,
      childAnchor: childAnchor,
      portalAnchor: dropdownAnchor,
      portal: FocusTraversalOrder(
        order: NumericFocusOrder(2),
        child: FocusTraversalGroup(
          child: Focus(
            skipTraversal: true,
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                isOpen.value = false;
              }
            },
            child: Material(
              elevation: 4.0,
              borderRadius: const BorderRadius.all(Radius.circular(3.0)),
              child: width == null
                  ? IntrinsicWidth(child: dropdown)
                  : ConstrainedBox(constraints: BoxConstraints.tightFor(width: width)),
            ),
          ),
        ),
      ),
      child: FocusTraversalOrder(
        order: NumericFocusOrder(1),
        child: TextButton(
          focusNode: focusNode,
          style: style,
          onPressed: () {
            isOpen.value = !isOpen.value;
            if (isOpen.value == true) {
              SchedulerBinding.instance?.addPostFrameCallback((_) => focusNode.nextFocus());
            }
          },
          child: child,
        ),
      ),
    ),
  );
}
