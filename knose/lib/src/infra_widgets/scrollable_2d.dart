import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';

part 'scrollable_2d.g.dart';

@reader_widget
Widget _scrollable2D(BuildContext context, {required Widget child}) {
  final transformationController = useTransformationController();

  return Listener(
    onPointerSignal: (signal) {
      final shiftPressed = isKeyPressed(context, LogicalKeyboardKey.shiftLeft) ||
          isKeyPressed(context, LogicalKeyboardKey.shiftRight) ||
          isKeyPressed(context, LogicalKeyboardKey.shift);

      if (signal is PointerScrollEvent) {
        final currentMatrix = transformationController.value;
        final currentTranslation = currentMatrix.getTranslation();
        transformationController.value = currentMatrix.clone()
          ..setTranslationRaw(
            math.min(
                0.0,
                currentTranslation.x +
                    (shiftPressed ? signal.scrollDelta.dy : signal.scrollDelta.dx)),
            math.min(0.0, currentTranslation.y + (shiftPressed ? 0.0 : signal.scrollDelta.dy)),
            0,
          );
      }
    },
    child: InteractiveViewer(
      transformationController: transformationController,
      clipBehavior: Clip.hardEdge,
      scaleEnabled: false,
      constrained: false,
      child: child,
    ),
  );
}
