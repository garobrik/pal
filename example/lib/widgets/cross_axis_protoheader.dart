import 'package:boxy/boxy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'cross_axis_protoheader.g.dart';

@bound_widget
Widget _crossAxisProtoheader({required Widget Function(bool) header, required Widget Function(ScrollController) body}) {
  final scrollController = useScrollController();
  final isScrolled = useState(false);
  scrollController.addListener(() {
    isScrolled.value = scrollController.offset != 0;
  });

  return PrimaryScrollController(
    controller: scrollController,
    child: CustomBoxy(
      delegate: _CrossAxisProtoHeaderDelegate(),
      children: [
        body(scrollController),
        IntrinsicWidth(child: header(isScrolled.value)),
      ],
    ),
  );
}

class _CrossAxisProtoHeaderDelegate extends BoxyDelegate<CrossAxisProtoheader> {
  @override
  Size layout() {
    final header = getChild(1);
    final body = getChild(0);

    final headerSize = header.layout(constraints);
    header.position(Offset.zero);

    final bodySize = body.layout(
      constraints.deflate(EdgeInsets.only(top: headerSize.height)).tighten(width: headerSize.width),
    );
    body.position(Offset(0, headerSize.height));

    return Size(headerSize.width, headerSize.height + bodySize.height);
  }
}
