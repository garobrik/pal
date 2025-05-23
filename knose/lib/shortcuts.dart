import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'shortcuts.g.dart';

final shortcuts = <ShortcutActivator, Intent>{
  ...WidgetsApp.defaultShortcuts,
  const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): const GoBackIntent(),
  const SingleActivator(LogicalKeyboardKey.escape):
      const PrioritizedIntents(orderedIntents: [UnfocusFieldIntent(), DismissIntent()]),
};

final actions = {
  ...WidgetsApp.defaultActions,
  UnfocusFieldIntent: UnfocusFieldAction(),
  NextFocusFieldIntent: NextFocusFieldAction(),
};

@reader
Widget _knoseActions(BuildContext context, {required Widget child}) {
  return Shortcuts(
    shortcuts: {LogicalKeySet(LogicalKeyboardKey.enter): NextFocusFieldIntent()},
    child: Actions(
      actions: {GoBackIntent: GoBackAction()},
      child: child,
    ),
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
    return null;
  }
}

class UnfocusFieldIntent extends Intent {
  const UnfocusFieldIntent();
}

class UnfocusFieldAction extends Action<UnfocusFieldIntent> {
  @override
  Object? invoke(covariant UnfocusFieldIntent intent, [BuildContext? context]) {
    primaryFocus?.unfocus();
    return null;
  }
}

class NextFocusFieldIntent extends Intent {}

class NextFocusFieldAction extends Action<NextFocusFieldIntent> {
  @override
  Object? invoke(covariant NextFocusFieldIntent intent, [BuildContext? context]) {
    primaryFocus?.nextFocus();
    return null;
  }
}
