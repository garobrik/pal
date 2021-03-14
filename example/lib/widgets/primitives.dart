import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'primitives.g.dart';

@bound_widget
Widget _boundTextField(
  BuildContext context,
  Cursor<String> text, {
  int? maxLines = 1,
  TextInputType? keyboardType,
  InputDecoration? decoration,
  TextStyle? style,
  TextAlignVertical? textAlignVertical,
}) {
  final textController = useTextEditingController(text: text.get);
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
            return true;
          } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
            if (!keyEvent.isShiftPressed) {
              focus.nextFocus();
              return true;
            }
          }
          return false;
        },
        child: TextFormField(
          maxLines: maxLines,
          controller: textController,
          keyboardType: keyboardType,
          decoration: decoration,
          style: style,
          textAlignVertical: textAlignVertical,
          onChanged: (newText) => text.set(newText),
        ),
      ),
    ),
  );
}

@bound_widget
Widget _dropdown({
  required Widget child,
  required Widget dropdown,
  Alignment? childAnchor,
  Alignment? dropdownAnchor,
  bool isOpenOnHover = true,
  ButtonStyle? style,
}) {
  final isOpen = useState(false);
  final focusNode = useFocusNode();

  return FocusTraversalGroup(
    child: Focus(
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          isOpen.value = false;
        }
      },
      child: PortalEntry(
        visible: isOpen.value,
        childAnchor: childAnchor,
        portalAnchor: dropdownAnchor,
        portal: FocusTraversalGroup(
          child: Material(
            elevation: 4.0,
            borderRadius: const BorderRadius.all(Radius.circular(3.0)),
            child: dropdown,
          ),
        ),
        child: TextButton(
          focusNode: focusNode,
          style: style,
          onPressed: () {
            isOpen.value = !isOpen.value;
            if (isOpen.value == true) {
              focusNode.requestFocus();
            }
          },
          child: child,
        ),
      ),
    ),
  );
}
