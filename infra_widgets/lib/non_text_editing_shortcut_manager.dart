import 'package:flutter/widgets.dart';

class NonTextEditingShortcutManager extends ShortcutManager {
  NonTextEditingShortcutManager({required super.shortcuts});

  @override
  KeyEventResult handleKeypress(BuildContext context, RawKeyEvent event) {
    if (primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null) {
      return KeyEventResult.ignored;
    }
    return super.handleKeypress(context, event);
  }
}
