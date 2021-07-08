import 'package:flutter/widgets.dart';

class _RectNotBottomClipper extends CustomClipper<Rect> {
  const _RectNotBottomClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, size.height + 100);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class ClipRectNotBottom extends StatelessWidget {
  final Widget child;
  final Clip clipBehaviour;

  const ClipRectNotBottom({Key? key, this.clipBehaviour = Clip.hardEdge, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: const _RectNotBottomClipper(),
      clipBehavior: clipBehaviour,
      child: child,
    );
  }
}
