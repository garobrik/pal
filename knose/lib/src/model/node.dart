import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';
import 'package:knose/model.dart' hide List;
import 'package:flutter/widgets.dart' as flutter;

part 'node.g.dart';

@immutable
class NodeID<T extends Node> extends UUID<NodeID<T>> {
  NodeID() : super();
  NodeID.from(String id) : super.from(id);
}

abstract class Node {
  NodeID get id;
}

@immutable
@reify
abstract class TitledNode extends Node with _TitledNodeMixin {
  @override
  NodeID<TitledNode> get id;

  @reify
  String get title;
  @reify
  TitledNode mut_title(String title);
}

typedef NodeBuilderFn<N> = flutter.Widget Function({
  required Cursor<State> state,
  required Cursor<N> node,
  flutter.FocusNode? defaultFocus,
});

@immutable
abstract class NodeBuilder {
  NodeBuilderFn<Node> get build;
}

@immutable
abstract class TypedNodeBuilder<N extends Node> implements NodeBuilder {
  @override
  NodeBuilderFn<Node> get build =>
      ({required state, required node, defaultFocus}) => buildTyped(
            state: state,
            node: node.cast<N>(),
            defaultFocus: defaultFocus,
          );

  NodeBuilderFn<N> get buildTyped;
}

@immutable
@reify
class NodeView<N extends Node> with _NodeViewMixin implements Node {
  @override
  final NodeID<NodeView> id;

  @override
  final NodeID<N> nodeID;

  @override
  final NodeBuilder builder;

  NodeView._({
    NodeID<NodeView>? id,
    required this.nodeID,
    required this.builder,
  }) : id = id ?? NodeID<NodeView>();

  static NodeView<N> from<N extends Node>({
    NodeID<NodeView>? id,
    required NodeID<N> nodeID,
    required TypedNodeBuilder<N> builder,
  }) {
    return NodeView._(
      id: id ?? NodeID<NodeView<N>>(),
      nodeID: nodeID,
      builder: builder,
    );
  }
}

@immutable
@reify
class Text with _TextMixin implements Node {
  @override
  final NodeID<Text> id;

  @override
  final Vec<TextElement> elements;

  Text([this.elements = const Vec([PlainText('')]), NodeID<Text>? id])
      : id = id ?? NodeID();
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
  final NodeID<NodeView> view;

  InlineNode(this.view);
}
