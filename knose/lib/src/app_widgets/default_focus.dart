import 'package:ctx/ctx.dart';
import 'package:flutter/widgets.dart';

class _DefaultFocus extends CtxElement {
  final FocusNode defaultFocus;

  _DefaultFocus(this.defaultFocus);
}

extension DefaultFocusExtension on Ctx {
  Ctx withDefaultFocus(FocusNode focusNode) => withElement(_DefaultFocus(focusNode));
  FocusNode? get defaultFocus => get<_DefaultFocus>()?.defaultFocus;
}
