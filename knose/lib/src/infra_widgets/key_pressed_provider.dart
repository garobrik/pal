import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:provider/provider.dart';

part 'key_pressed_provider.g.dart';

@reader
Widget keyPressedProvider({required Widget child}) {
  final lastEvent = useRef<RawKeyEvent?>(null);

  return Focus(
    onKey: (_, keyEvent) {
      lastEvent.value = keyEvent;
      return KeyEventResult.ignored;
    },
    child: Provider.value(
      value: lastEvent,
      child: child,
    ),
  );
}

bool isKeyPressed(BuildContext context, LogicalKeyboardKey key) {
  return Provider.of<ObjectRef<RawKeyEvent?>>(context, listen: false).value?.isKeyPressed(key) ??
      false;
}
