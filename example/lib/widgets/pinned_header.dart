import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SliverPinnedHeader extends RenderObjectWidget {
  const SliverPinnedHeader({
    Key? key,
    required this.builder,
  }) : super(
          key: key,
          // delegate: delegate,
        );

  final Widget Function(BuildContext, bool) builder;

  @override
  SliverPinnedHeaderElement createElement() => SliverPinnedHeaderElement(this);

  @override
  RenderSliverPinnedPersistentHeader createRenderObject(BuildContext context) {
    return RenderSliverPinnedPersistentHeader(
        // stretchConfiguration: delegate.stretchConfiguration,
        // showOnScreenConfiguration: delegate.showOnScreenConfiguration,
        );
  }
}

class SliverPinnedHeaderElement extends RenderObjectElement {
  SliverPinnedHeaderElement(SliverPinnedHeader widget) : super(widget);

  @override
  SliverPinnedHeader get widget => super.widget as SliverPinnedHeader;

  @override
  RenderSliverPinnedPersistentHeader get renderObject =>
      super.renderObject as RenderSliverPinnedPersistentHeader;

  @override
  void mount(Element? parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    renderObject._element = this;
  }

  @override
  void unmount() {
    super.unmount();
    renderObject._element = null;
  }

  @override
  void performRebuild() {
    super.performRebuild();
    renderObject.markNeedsLayout();
  }

  Element? child;

  void _build(bool overlapsContent) {
    owner!.buildScope(this, () {
      child = updateChild(
        child,
        widget.builder(this, overlapsContent),
        null,
      );
    });
  }

  @override
  void forgetChild(Element child) {
    assert(child == this.child);
    this.child = null;
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(covariant RenderBox child, dynamic slot) {
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
  }

  @override
  void moveRenderObjectChild(covariant RenderObject child, dynamic oldSlot, dynamic newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(covariant RenderObject child, dynamic slot) {
    renderObject.child = null;
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (child != null) visitor(child!);
  }
}

/// A sliver with a [RenderBox] child which never scrolls off the viewport in
/// the positive scroll direction, and which first scrolls on at a full size but
/// then shrinks as the viewport continues to scroll.
///
/// This sliver avoids overlapping other earlier slivers where possible.
class RenderSliverPinnedPersistentHeader extends RenderSliver
    with RenderObjectWithChildMixin<RenderBox>, RenderSliverHelpers {
  SliverPinnedHeaderElement? _element;

  /// Creates a sliver that shrinks when it hits the start of the viewport, then
  /// stays pinned there.
  RenderSliverPinnedPersistentHeader({
    RenderBox? child,
    // OverScrollHeaderStretchConfiguration? stretchConfiguration,
    // this.showOnScreenConfiguration = const PersistentHeaderShowOnScreenConfiguration(),
  }) // : super(
  //      stretchConfiguration: stretchConfiguration,
  //    )
  {
    this.child = child;
  }

  // /// Specifies the persistent header's behavior when `showOnScreen` is called.
  // ///
  // /// If set to null, the persistent header will delegate the `showOnScreen` call
  // /// to it's parent [RenderObject].
  // PersistentHeaderShowOnScreenConfiguration? showOnScreenConfiguration;

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    final bool overlapsContent = constraints.scrollOffset > 0;
    layoutChild(overlapsContent);

    final paintedChildExtent = min(
      childExtent,
      constraints.remainingPaintExtent - constraints.overlap,
    );
    geometry = SliverGeometry(
      paintExtent: paintedChildExtent,
      maxPaintExtent: childExtent,
      maxScrollObstructionExtent: childExtent,
      paintOrigin: constraints.overlap,
      scrollExtent: childExtent,
      layoutExtent: max(0.0, paintedChildExtent - constraints.scrollOffset),
      hasVisualOverflow: paintedChildExtent < childExtent,
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) => 0.0;

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    final Rect? localBounds = descendant != null
        ? MatrixUtils.transformRect(descendant.getTransformTo(this), rect ?? descendant.paintBounds)
        : rect;

    Rect? newRect;
    switch (applyGrowthDirectionToAxisDirection(
        constraints.axisDirection, constraints.growthDirection)) {
      case AxisDirection.up:
        newRect = _trim(localBounds, bottom: childExtent);
        break;
      case AxisDirection.right:
        newRect = _trim(localBounds, left: 0);
        break;
      case AxisDirection.down:
        newRect = _trim(localBounds, top: 0);
        break;
      case AxisDirection.left:
        newRect = _trim(localBounds, right: childExtent);
        break;
    }

    super.showOnScreen(
      descendant: this,
      rect: newRect,
      duration: duration,
      curve: curve,
    );
  }

  /// The dimension of the child in the main axis.
  @protected
  double get childExtent {
    if (child == null) {
      return 0.0;
    }
    assert(child!.hasSize);
    switch (constraints.axis) {
      case Axis.vertical:
        return child!.size.height;
      case Axis.horizontal:
        return child!.size.width;
    }
  }

  bool _needsUpdateChild = true;
  bool _lastOverlapsContent = false;

  /// Defines the parameters used to execute an [AsyncCallback] when a
  /// stretching header over-scrolls.
  ///
  /// If [stretchConfiguration] is null then callback is not triggered.
  ///
  /// See also:
  ///
  ///  * [SliverAppBar], which creates a header that can stretched into an
  ///    overscroll area and trigger a callback function.
  OverScrollHeaderStretchConfiguration? stretchConfiguration;

  /// Update the child render object if necessary.
  ///
  /// Called before the first layout, any time [markNeedsLayout] is called, and
  /// any time the scroll offset changes. The `shrinkOffset` is the difference
  /// between the [maxExtent] and the current size. Zero means the header is
  /// fully expanded, any greater number up to [maxExtent] means that the header
  /// has been scrolled by that much. The `overlapsContent` argument is true if
  /// the sliver's leading edge is beyond its normal place in the viewport
  /// contents, and false otherwise. It may still paint beyond its normal place
  /// if the [minExtent] after this call is greater than the amount of space that
  /// would normally be left.
  ///
  /// The render object will size itself to the larger of (a) the [maxExtent]
  /// minus the child's intrinsic height and (b) the [maxExtent] minus the
  /// shrink offset.
  ///
  /// When this method is called by [layoutChild], the [child] can be set,
  /// mutated, or replaced. (It should not be called outside [layoutChild].)
  ///
  /// Any time this method would mutate the child, call [markNeedsLayout].
  @protected
  void updateChild(bool overlapsContent) => _element?._build(overlapsContent);

  @override
  void markNeedsLayout() {
    // This is automatically called whenever the child's intrinsic dimensions
    // change, at which point we should remeasure them during the next layout.
    _needsUpdateChild = true;
    super.markNeedsLayout();
  }

  /// Lays out the [child].
  ///
  /// This is called by [performLayout]. It applies the given `scrollOffset`
  /// (which need not match the offset given by the [constraints]) and the
  /// `maxExtent` (which need not match the value returned by the [maxExtent]
  /// getter).
  ///
  /// The `overlapsContent` argument is passed to [updateChild].
  @protected
  void layoutChild(bool overlapsContent) {
    if (_needsUpdateChild || _lastOverlapsContent != overlapsContent) {
      invokeLayoutCallback<SliverConstraints>((SliverConstraints constraints) {
        assert(constraints == this.constraints);
        updateChild(overlapsContent);
      });
      _lastOverlapsContent = overlapsContent;
      _needsUpdateChild = false;
    }

    child?.layout(constraints.asBoxConstraints(), parentUsesSize: true);
  }

  @override
  bool hitTestChildren(SliverHitTestResult result,
      {required double mainAxisPosition, required double crossAxisPosition}) {
    assert(geometry!.hitTestExtent > 0.0);
    if (child != null) {
      return hitTestBoxChild(BoxHitTestResult.wrap(result), child!,
          mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    assert(child == this.child);
    applyPaintTransformForBoxChild(child as RenderBox, transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && geometry!.visible) {
      switch (applyGrowthDirectionToAxisDirection(
          constraints.axisDirection, constraints.growthDirection)) {
        case AxisDirection.up:
          offset +=
              Offset(0.0, geometry!.paintExtent - childMainAxisPosition(child!) - childExtent);
          break;
        case AxisDirection.down:
          offset += Offset(0.0, childMainAxisPosition(child!));
          break;
        case AxisDirection.left:
          offset +=
              Offset(geometry!.paintExtent - childMainAxisPosition(child!) - childExtent, 0.0);
          break;
        case AxisDirection.right:
          offset += Offset(childMainAxisPosition(child!), 0.0);
          break;
      }
      context.paintChild(child!, offset);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.addTagForChildren(RenderViewport.excludeFromScrolling);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty.lazy('child position', () => childMainAxisPosition(child!)));
  }

  Rect? _trim(
    Rect? original, {
    double top = -double.infinity,
    double right = double.infinity,
    double bottom = double.infinity,
    double left = -double.infinity,
  }) =>
      original?.intersect(Rect.fromLTRB(left, top, right, bottom));
}
