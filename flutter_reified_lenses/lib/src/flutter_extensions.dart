import 'package:flutter/widgets.dart';
import 'package:reified_lenses/reified_lenses.dart';

extension GetCursorFlutterExtension<C extends GetCursor, S> on Zoom<C, S> {
  Widget build(Widget Function(S) builder, {Key key}) {
    return Builder(key: key, builder: (context) {
      final value = this.get(() => (context as Element).markNeedsBuild());
      return builder(value);
    });
  }
}
