import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';

part 'cell_dropdown.g.dart';

@reader
Widget _cellDropdown(
  BuildContext context, {
  required Ctx ctx,
  required Widget dropdown,
  required Widget child,
  ButtonStyle? style,
  FocusNode? dropdownFocus,
  bool expands = true,
  bool enabled = true,
}) {
  final minWidth = useMemoized(() => expands ? 200.0 : 0.0, [expands]);

  return TextButtonDropdown(
    enabled: enabled,
    modifyConstraints: (constraints) => BoxConstraints(
      minHeight: constraints.maxHeight + 2,
      maxHeight: constraints.maxHeight + 2,
      minWidth: constraints.maxWidth + 2,
      maxWidth: max(minWidth, constraints.maxWidth + 2),
    ),
    dropdownFocus: dropdownFocus,
    offset: const Offset(-1, -1),
    childAnchor: Alignment.topLeft,
    dropdown: ModifiedIntrinsicWidth(
      modification: 2,
      child: dropdown,
    ),
    style: style,
    child: child,
  );
}
