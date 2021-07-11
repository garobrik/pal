import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ModifiedIntrinsicWidth extends SingleChildRenderObjectWidget {
  final double modification;

  /// Creates a widget that sizes its child to the child's intrinsic height.
  ///
  /// This class is relatively expensive. Avoid using it where possible.
  const ModifiedIntrinsicWidth({
    Key? key,
    required this.modification,
    Widget? child,
  }) : super(key: key, child: child);

  @override
  RenderModifiedIntrinsicWidth createRenderObject(BuildContext context) =>
  RenderModifiedIntrinsicWidth(modification: modification);

  @override
  void updateRenderObject(BuildContext context, RenderModifiedIntrinsicWidth renderObject) {
    renderObject.modification = modification;
  }
}

class RenderModifiedIntrinsicWidth extends RenderProxyBox {
  RenderModifiedIntrinsicWidth({
    required double modification,
    RenderBox? child,
  })  : _modification = modification,
        super(child);

  /// If non-null, force the child's width to be a multiple of this value.
  ///
  /// This value must be null or > 0.0.
  double get modification => _modification;
  double _modification;
  set modification(double value) {
    if (value == _modification) return;
    _modification = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child == null) {
      return 0.0;
    }
    if (!width.isFinite) {
      width = child!.getMaxIntrinsicWidth(double.infinity);
    }
    assert(width.isFinite);
    return child!.getMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child == null) {
      return 0.0;
    }
    if (!width.isFinite) {
      width = child!.getMaxIntrinsicWidth(double.infinity);
    }
    assert(width.isFinite);
    return child!.getMaxIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child != null) return child!.getMaxIntrinsicWidth(height) + modification;
    return 0.0;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return computeMaxIntrinsicWidth(height);
  }

  Size _computeSize({required ChildLayouter layoutChild, required BoxConstraints constraints}) {
    if (child != null) {
      if (!constraints.hasTightWidth) {
        final double width = child!.getMaxIntrinsicWidth(constraints.maxHeight);
        assert(width.isFinite);
        constraints = constraints.tighten(width: width + modification);
      }
      return layoutChild(child!, constraints);
    } else {
      return constraints.smallest;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      layoutChild: ChildLayoutHelper.dryLayoutChild,
      constraints: constraints,
    );
  }

  @override
  void performLayout() {
    size = _computeSize(
      layoutChild: ChildLayoutHelper.layoutChild,
      constraints: constraints,
    );
  }
}
