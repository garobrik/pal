import 'package:flutter/widgets.dart';

class AlignedWidgetSpan extends WidgetSpan {
  const AlignedWidgetSpan(Widget child)
      : super(
          child: child,
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
        );
}
