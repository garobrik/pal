import 'dart:collection';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:knose/infra_widgets.dart';

class DeferredPaintTarget extends StatefulWidget {
  final Widget child;

  const DeferredPaintTarget({Key? key, required this.child}) : super(key: key);

  @override
  State<StatefulWidget> createState() => DeferredPaintTargetState();
}

class DeferredPaintTargetState extends State<DeferredPaintTarget> {
  final link = DeferredPaintLink();

  @override
  Widget build(BuildContext context) {
    return InheritedValue(
      value: link,
      child: DeferredPaintTargetRenderObject(
        link: link,
        child: widget.child,
      ),
    );
  }
}

class DeferredPainter extends StatelessWidget {
  final Widget child;

  const DeferredPainter({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final link = InheritedValue.of<DeferredPaintLink>(context);
    return DeferredPainterRenderObject(
      link: link,
      child: child,
    );
  }
}

class DeferredPaintLink extends ChangeNotifier {
  final List<RenderBox> _renderBoxes = [];
  List<RenderBox> get renderBoxes {
    return UnmodifiableListView(_renderBoxes);
  }

  void add(RenderBox deferredPainter) {
    if (!_renderBoxes.contains(deferredPainter)) {
      _renderBoxes.add(deferredPainter);
      notifyListeners();
    }
  }

  void remove(RenderBox deferredPainter) {
    if (_renderBoxes.contains(deferredPainter)) {
      _renderBoxes.remove(deferredPainter);
      notifyListeners();
    }
  }

  void markNeedsPaint() => notifyListeners();

  DeferredPaintLink();
}

class DeferredPainterRenderObject extends SingleChildRenderObjectWidget {
  const DeferredPainterRenderObject({required this.link, Widget? child, Key? key})
      : super(child: child, key: key);

  final DeferredPaintLink link;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderDeferredPainter(link);
  }

  @override
  void updateRenderObject(BuildContext context, RenderDeferredPainter renderObject) {
    renderObject.link = link;
  }
}

class RenderDeferredPainter extends RenderProxyBox {
  RenderDeferredPainter(DeferredPaintLink link, {RenderBox? child}) : super(child) {
    this.link = link;
  }

  bool _linked = false;

  DeferredPaintLink? _link;
  DeferredPaintLink get link => _link!;
  set link(DeferredPaintLink link) {
    if (_linked) {
      link.remove(this.child!);
      _linked = false;
    }
    _link = link;
    if (_link != null && this.child != null) {
      link.add(this.child!);
      _linked = true;
    }
  }

  @override
  set child(RenderBox? child) {
    if (_linked) {
      link.remove(this.child!);
      _linked = false;
    }
    super.child = child;
    if (_link != null && this.child != null) {
      link.add(this.child!);
      _linked = true;
    }
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);
    if (!_linked && _link != null && this.child != null) {
      link.add(this.child!);
    }
  }

  @override
  void detach() {
    if (_linked) {
      link.remove(this.child!);
    }
    super.detach();
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0.0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0.0;

  @override
  double computeMinIntrinsicHeight(double width) => 0.0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0.0;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      super.computeDistanceToActualBaseline(baseline);

  @override
  Size computeDryLayout(BoxConstraints constraints) => computeSizeForNoChild(constraints);

  @override
  void performLayout() {
    child?.layout(constraints, parentUsesSize: true);
    size = computeSizeForNoChild(constraints);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {}

  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    link.markNeedsPaint();
  }
}

class DeferredPaintTargetRenderObject extends SingleChildRenderObjectWidget {
  const DeferredPaintTargetRenderObject({required this.link, Widget? child, Key? key})
      : super(child: child, key: key);

  final DeferredPaintLink link;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderDeferredPaintTarget(link);
  }

  @override
  void updateRenderObject(BuildContext context, RenderDeferredPaintTarget renderObject) {
    renderObject.link = link;
  }
}

class RenderDeferredPaintTarget extends RenderProxyBox {
  RenderDeferredPaintTarget(DeferredPaintLink link, [RenderBox? child]) : super(child) {
    this.link = link;
  }

  DeferredPaintLink? _link;
  DeferredPaintLink get link => _link!;
  set link(DeferredPaintLink link) {
    if (_link != null) {
      _link!.removeListener(this.markNeedsPaint);
    }
    _link = link;
    this.link.addListener(this.markNeedsPaint);
    markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    for (final renderBox in link.renderBoxes.reversed) {
      final hit = result.addWithPaintTransform(
        transform: renderBox.getTransformTo(this),
        position: position,
        hitTest: (BoxHitTestResult result, Offset? position) {
          return renderBox.hitTest(result, position: position!);
        },
      );
      if (hit) {
        return true;
      }
    }
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    for (final renderBox in link.renderBoxes) {
      context.paintChild(renderBox, renderBox.localToGlobal(Offset.zero, ancestor: this) + offset);
    }
  }
}
