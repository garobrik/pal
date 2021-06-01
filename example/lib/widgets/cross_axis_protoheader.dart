import 'package:boxy/boxy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'cross_axis_protoheader.g.dart';

@reader_widget
Widget _crossAxisProtoheader({
  required Widget header,
  required Widget body,
}) {
  return CustomBoxy(
    delegate: _CrossAxisProtoHeaderDelegate(),
    children: [
      IntrinsicWidth(child: header),
      body,
    ],
  );
}

class _CrossAxisProtoHeaderDelegate extends BoxyDelegate<CrossAxisProtoheader> {
  @override
  Size layout() {
    final header = getChild(0);
    final body = getChild(1);

    final headerSize = header.layout(constraints);
    header.position(Offset.zero);

    final bodySize = body.layout(
      constraints.deflate(EdgeInsets.only(top: headerSize.height)).tighten(width: headerSize.width),
    );
    body.position(Offset(0, headerSize.height));

    return Size(headerSize.width, headerSize.height + bodySize.height);
  }
}
