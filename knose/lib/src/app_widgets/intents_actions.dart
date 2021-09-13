import 'package:flutter/widgets.dart';

class NewNodeBelowIntent extends Intent {
  const NewNodeBelowIntent();
}

class DeleteNodeIntent extends Intent {
  const DeleteNodeIntent();
}

typedef NewNodeBelowAction = CallbackAction<NewNodeBelowIntent>;

class ConfigureNodeViewIntent extends Intent {
  const ConfigureNodeViewIntent();
}

abstract class CallbackContextAction<T extends Intent> extends ContextAction<T> {
  factory CallbackContextAction({
    required Object? Function(T intent, BuildContext? context) onInvoke,
    bool Function(T intent)? onConsumesKey,
    bool textEditing = false,
  }) =>
      textEditing
          ? _CallbackContextTextEditingAction(
              onInvoke: onInvoke,
              onConsumesKey: onConsumesKey,
            )
          : _CallbackContextNotTextEditingAction(
              onInvoke: onInvoke,
              onConsumesKey: onConsumesKey,
            );
}

class _CallbackContextNotTextEditingAction<T extends Intent> extends ContextAction<T>
    implements CallbackContextAction<T> {
  final Object? Function(T intent, BuildContext? context) onInvoke;
  final bool Function(T intent)? onConsumesKey;

  _CallbackContextNotTextEditingAction({required this.onInvoke, this.onConsumesKey});

  @override
  Object? invoke(covariant T intent, [BuildContext? context]) => onInvoke(intent, context);

  @override
  bool consumesKey(covariant T intent) => onConsumesKey == null ? true : onConsumesKey!(intent);
}

class _CallbackContextTextEditingAction<T extends Intent> extends TextEditingAction<T>
    implements CallbackContextAction<T> {
  final Object? Function(T intent, BuildContext? context) onInvoke;
  final bool Function(T intent)? onConsumesKey;

  _CallbackContextTextEditingAction({required this.onInvoke, this.onConsumesKey});

  @override
  Object? invoke(covariant T intent, [BuildContext? context]) => onInvoke(intent, context);

  @override
  bool consumesKey(covariant T intent) => onConsumesKey == null ? true : onConsumesKey!(intent);
}
