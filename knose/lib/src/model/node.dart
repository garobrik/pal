import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';
import 'package:knose/model.dart';

part 'node.g.dart';

@immutable
class NodeID extends UUID<NodeID> {
  NodeID.from(String id) : super.from(id);
}

@immutable
@ReifiedLens(cases: [TableView, PageView, CustomView])
abstract class NodeViewer {
  const NodeViewer();
}

@immutable
@reify
class TableView extends NodeViewer {
  const TableView();
}

@immutable
@reify
class PageView extends NodeViewer {
  const PageView();
}

@immutable
@reify
class CustomView extends NodeViewer {
  const CustomView();
}

@immutable
@reify
class NodeView with _NodeViewMixin {
  @override
  final NodeID node;

  @override
  final NodeViewer viewer;

  const NodeView({
    required this.node,
    required this.viewer,
  });
}

@immutable
@reify
class Text with _TextMixin {
  @override
  final Vec<TextElement> elements;

  const Text([this.elements = const Vec([PlainText('')])]);
}

@immutable
@ReifiedLens(cases: [PlainText, InlineNode])
class TextElement with _TextElementMixin {
  const TextElement();
}

@immutable
@reify
class PlainText extends TextElement with _PlainTextMixin {
  @override
  final String text;

  const PlainText(this.text);
}

@immutable
@reify
class InlineNode extends TextElement with _InlineNodeMixin {
  @override
  final NodeView view;

  InlineNode(this.view);
}
