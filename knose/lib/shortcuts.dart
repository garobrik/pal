import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'shortcuts.g.dart';

final shortcuts = <LogicalKeySet, Intent>{
  ...WidgetsApp.defaultShortcuts,
  for (final alt in [
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.alt
  ])
    LogicalKeySet(LogicalKeyboardKey.arrowLeft, alt): GoBackIntent(),
    LogicalKeySet(LogicalKeyboardKey.escape): PrioritizedIntents(orderedIntents: [UnfocusFieldIntent(), DismissIntent()]),
};

final actions = {
  ...WidgetsApp.defaultActions,
  UnfocusFieldIntent: UnfocusFieldAction(),
};

@reader_widget
Widget _knoseActions(BuildContext context, {required Widget child}) {
  return Actions(
    actions: {GoBackIntent: GoBackAction()},
    child: child,
  );
}

class GoBackIntent extends Intent {
  const GoBackIntent();
}

class GoBackAction extends ContextAction<GoBackIntent> {
  GoBackAction();

  @override
  Object? invoke(covariant GoBackIntent intent, [BuildContext? context]) {
    if (context == null) return null;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.maybePop();
  }
}

class UnfocusFieldIntent extends Intent {}

class UnfocusFieldAction extends TextEditingAction<UnfocusFieldIntent> {
  @override
  Object? invoke(covariant UnfocusFieldIntent intent, [BuildContext? context]) {
    primaryFocus?.unfocus();
  }
}
