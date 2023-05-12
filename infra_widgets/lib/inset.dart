import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class InlineInset extends Inset {
  InlineInset({required super.contents, super.key})
      : super(
          prefix: const SizedBox(),
          suffix: const SizedBox(),
          inset: EdgeInsets.zero,
          drawGuideLine: false,
        );
}

class Inset extends MultiChildRenderObjectWidget {
  final EdgeInsetsGeometry inset;
  final bool drawGuideLine;

  Inset({
    required Widget prefix,
    required List<Widget> contents,
    Widget suffix = const SizedBox(),
    this.inset = const EdgeInsetsDirectional.only(start: 10, end: 2),
    this.drawGuideLine = true,
    bool repaintBoundaries = false,
    super.key,
  }) : super(
          children: repaintBoundaries
              ? RepaintBoundary.wrapAll([prefix, ...contents, suffix])
              : [prefix, ...contents, suffix],
        );

  @override
  RenderObject createRenderObject(BuildContext context) => RenderInset(
        inset: inset,
        textDirection: Directionality.of(context),
        drawGuideLine: drawGuideLine,
      );

  @override
  void updateRenderObject(BuildContext context, covariant RenderInset renderObject) {
    renderObject
      ..inset = inset
      ..textDirection = Directionality.of(context)
      ..drawGuideLine = drawGuideLine;
  }
}

class InsetParentData extends ContainerBoxParentData<RenderBox> {}

class _InsetChildren {
  final List<RenderBox> children;

  _InsetChildren(this.children);

  RenderBox get prefix => children.first;
  RenderBox get suffix => children.last;
  Iterable<RenderBox> get contents => children.sublist(1, children.length - 1);
  Iterable<RenderBox> get all => children;
}

class RenderInset extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, InsetParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, InsetParentData> {
  static const textBaseline = TextBaseline.alphabetic;

  RenderInset({
    required EdgeInsetsGeometry inset,
    required TextDirection textDirection,
    required bool drawGuideLine,
  })  : _inset = inset,
        _textDirection = textDirection,
        _drawGuideLine = drawGuideLine;

  EdgeInsetsGeometry get inset => _inset;
  late EdgeInsetsGeometry _inset;
  set inset(EdgeInsetsGeometry value) {
    if (_inset != value) {
      _inset = value;
      markNeedsLayout();
    }
  }

  TextDirection get textDirection => _textDirection;
  late TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection != value) {
      _textDirection = value;
      markNeedsLayout();
    }
  }

  bool get drawGuideLine => _drawGuideLine;
  late bool _drawGuideLine;
  set drawGuideLine(bool value) {
    if (_drawGuideLine != value) {
      _drawGuideLine = value;
      markNeedsLayout();
    }
  }

  InsetParentData _parentData(RenderBox child) => child.parentData as InsetParentData;
  _InsetChildren _children() {
    var contentIterator = firstChild!;
    final children = <RenderBox>[];
    while (_parentData(contentIterator).nextSibling != null) {
      children.add(contentIterator);
      contentIterator = _parentData(contentIterator).nextSibling!;
    }
    children.add(contentIterator);
    return _InsetChildren(children);
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! InsetParentData) {
      child.parentData = InsetParentData();
    }
  }

  @override
  void performLayout() {
    final children = _children();
    final prefix = children.prefix;
    final contents = children.contents;
    final suffix = children.suffix;

    prefix.layout(constraints.loosen(), parentUsesSize: true);
    for (final content in contents) {
      content.layout(
        constraints.loosen().deflate(inset.resolve(textDirection)),
        parentUsesSize: true,
      );
    }
    suffix.layout(constraints.loosen(), parentUsesSize: true);

    final newLine = _needsNewLine(constraints, children);
    double maxBaselineDistance = 0.0;
    if (!newLine) {
      final allocatedSize = Size(
        children.all.fold(0, (p, c) => p + c.size.width),
        children.all.map((c) => c.size.height).fold(0, max),
      );

      double height = allocatedSize.height;
      double maxSizeAboveBaseline = 0;
      double maxSizeBelowBaseline = 0;
      for (final child in [prefix, ...contents, suffix]) {
        final double? distance = child.getDistanceToBaseline(textBaseline, onlyReal: true);
        if (distance != null) {
          maxBaselineDistance = max(maxBaselineDistance, distance);
          maxSizeAboveBaseline = max(distance, maxSizeAboveBaseline);
          maxSizeBelowBaseline = max(child.size.height - distance, maxSizeBelowBaseline);
          height = max(maxSizeAboveBaseline + maxSizeBelowBaseline, height);
        }
      }
      size = constraints.constrain(Size(allocatedSize.width, height));
    } else {
      final double contentsHeight =
          contents.fold(0, (height, content) => height + content.size.height);
      size = constraints.constrain(Size(
        [
          contents.map((c) => c.size.width).fold(0.0, max) + _inset.collapsedSize.width,
          prefix.size.width,
          suffix.size.width,
        ].fold(0, max),
        contentsHeight + prefix.size.height + suffix.size.height,
      ));
    }

    if (newLine) {
      _parentData(prefix).offset = Offset.zero;
      var cumulativeHeight = prefix.size.height;
      for (final content in contents) {
        _parentData(content).offset = Offset(inset.resolve(textDirection).left, cumulativeHeight);
        cumulativeHeight += content.size.height;
      }
      _parentData(suffix).offset = Offset(0, cumulativeHeight);
    } else {
      var cumulativeWidth = 0.0;
      for (final child in [prefix, ...contents, suffix]) {
        late final double height;
        final double? distance = child.getDistanceToBaseline(textBaseline, onlyReal: true);
        if (distance != null) {
          height = maxBaselineDistance - distance;
        } else {
          height = 0.0;
        }
        _parentData(child).offset = Offset(cumulativeWidth, height);
        cumulativeWidth += child.size.width;
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    if (!drawGuideLine) return;
    final children = _children();
    if (_needsNewLine(constraints, children)) {
      context.canvas.drawRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + _parentData(children.contents.first).offset.dy,
          2,
          children.contents.fold(0.0, (height, content) => height + content.size.height),
        ),
        Paint()
          ..color = const Color(0xFF969696)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  bool _needsNewLine(
    BoxConstraints constraints,
    _InsetChildren children,
  ) {
    final double contentsWidth =
        children.contents.fold(0, (width, content) => width + content.size.width);

    final narrowEnough = contentsWidth <=
        constraints.maxWidth - (children.prefix.size.width + children.suffix.size.width);
    // TODO: compute the magic height constraint here properly
    final shortEnough = children.contents.map((c) => c.size.height).fold(0.0, max) <= 25;
    return !narrowEnough || !shortEnough;
  }
}
