import 'dart:async';

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
  void Function(String)? onSubmitted,
}) {
  final textController = useTextEditingController(text: text.get);
  useEffect(() {
    return text.listen(() => textController.text = text.get);
  }, [textController, text]);
  final keyboardFocusNode = useFocusNode(skipTraversal: true);

  return Form(
    child: Builder(
      builder: (context) => Focus(
        skipTraversal: true,
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            Form.of(context)!.save();
          }
        },
        child: RawKeyboardListener(
          focusNode: keyboardFocusNode,
          onKey: (keyEvent) {
            if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
              keyboardFocusNode.unfocus();
            } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
              if (!keyEvent.isShiftPressed) {
                keyboardFocusNode.unfocus();
              }
            }
          },
          child: TextFormField(
            maxLines: maxLines,
            controller: textController,
            keyboardType: keyboardType,
            decoration: decoration,
            style: style,
            textAlignVertical: textAlignVertical,
            onSaved: (newText) {
              text.set(newText!);
              if (onSubmitted != null) onSubmitted(newText);
            },
          ),
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
}) {
  final isParentHovered = useState(false);
  final isChildHovered = useState(false);
  final isOpen = useState(false);
  final focusNode = useFocusNode();
  if (isOpenOnHover) {
    useEffect(() {
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          isParentHovered.value = true;
        } else {
          isParentHovered.value = false;
        }
      });
    });
  }

  return RawKeyboardListener(
    focusNode: focusNode,
    onKey: (keyEvent) {
      if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
        isOpen.value = true;
      } else if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
        isOpen.value = false;
      }
    },
    child: ConditionalParent(
      condition: isOpenOnHover,
      parent: (child) => MouseRegion(
        onEnter: (_) => isParentHovered.value = true,
        onHover: (_) => isParentHovered.value = true,
        onExit: (_) => Timer(Duration(milliseconds: 10), () => isParentHovered.value = false),
        child: child,
      ),
      child: PortalEntry(
        visible: isOpen.value || isParentHovered.value || isChildHovered.value,
        childAnchor: childAnchor,
        portalAnchor: dropdownAnchor,
        portal: ConditionalParent(
          condition: isOpenOnHover,
          parent: (child) => MouseRegion(
            onEnter: (_) => isChildHovered.value = true,
            onHover: (_) => isChildHovered.value = true,
            onExit: (_) => Timer(Duration(milliseconds: 10), () => isChildHovered.value = false),
            child: child,
          ),
          child: Material(
            elevation: 4.0,
            borderRadius: const BorderRadius.all(Radius.circular(3.0)),
            child: dropdown,
          ),
        ),
        child: GestureDetector(
          onTap: () {
            if (!isParentHovered.value && !isChildHovered.value) {
              isOpen.value = !isOpen.value;
              focusNode.requestFocus();
            }
          },
          child: child,
        ),
      ),
    ),
  );
}

@bound_widget
Widget _conditionalParent(
    {required bool condition, required Widget child, required Widget Function(Widget) parent}) {
  if (condition) {
    return parent(child);
  } else {
    return child;
  }
}
