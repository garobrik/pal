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

typedef NodeBuilderFn = flutter.Widget Function({
  required Ctx ctx,
  required Dict<String, Cursor<Object>> fields,
  flutter.FocusNode? defaultFocus,
});

@immutable
abstract class NodeBuilder {
  const NodeBuilder();

  NodeBuilderFn get build;
  bool canBuild(Ctx ctx) => true;
  Dict<String, Datum> makeFields(
    Cursor<State> state,
    NodeID<NodeView> nodeView,
  );
  NodeID<NodeView> addView(Cursor<State> state) {
    final nodeView = NodeID<NodeView>();
    return state.addNode(NodeView(
      id: nodeView,
      nodeBuilder: this,
      fields: makeFields(state, nodeView),
    ));
  }
}

@immutable
abstract class TopLevelNodeBuilder extends NodeBuilder {
  const TopLevelNodeBuilder();

  Cursor<String> title({
    required Ctx ctx,
    required Dict<String, Cursor<Object>> fields,
  });

  @override
  NodeID<NodeView<TopLevelNodeBuilder>> addView(Cursor<State> state) {
    final nodeView = NodeID<NodeView<TopLevelNodeBuilder>>();
    return state.addNode(NodeView(
      id: nodeView,
      nodeBuilder: this,
      fields: makeFields(state, nodeView),
    ));
  }
}

@immutable
@reify
class NodeView<T extends NodeBuilder> with _NodeViewMixin<T> implements Node {
  @override
  final NodeID<NodeView<T>> id;

  @override
  final Dict<String, Datum> fields;

  @override
  final T nodeBuilder;

  NodeView({
    NodeID<NodeView<T>>? id,
    required this.nodeBuilder,
    required this.fields,
  }) : id = id ?? NodeID<NodeView<T>>();
}

extension NodeViewExtension on Cursor<NodeView> {
  flutter.Widget? build({
    required Ctx ctx,
    required Reader reader,
    flutter.FocusNode? defaultFocus,
  }) {
    final builder = nodeBuilder.read(reader);
    final fields = this.fields.read(reader);
    final fieldCursors = <String, Cursor<Object>>{};
    for (final entry in fields) {
      final cursor = entry.value.build(reader, ctx);
      if (cursor == null) return null;
      fieldCursors[entry.key] = cursor;
    }

    return builder.build(
      ctx: ctx,
      fields: Dict(fieldCursors),
      defaultFocus: defaultFocus,
    );
  }
}

extension TopLevelNodeViewExtension on Cursor<NodeView<TopLevelNodeBuilder>> {
  Cursor<String>? title({
    required Ctx ctx,
    required Reader reader,
  }) {
    final builder = nodeBuilder.read(reader);
    final fields = this.fields.read(reader);
    final fieldCursors = <String, Cursor<Object>>{};
    for (final entry in fields) {
      final cursor = entry.value.build(reader, ctx);
      if (cursor == null) return null;
      fieldCursors[entry.key] = cursor;
    }

    return builder.title(
      ctx: ctx,
      fields: Dict(fieldCursors),
    );
  }
}

@immutable
@reify
abstract class DataSource implements CtxElement {
  @reify
  GetCursor<Vec<Datum>> get data;
}

@immutable
@reify
abstract class Datum {
  const Datum();

  @reify
  GetCursor<String> name(Reader reader, Ctx ctx);

  Cursor<Object>? build(Reader reader, Ctx ctx);
}

@immutable
@reify
class Literal<T extends Object> extends Datum with _LiteralMixin<T> {
  const Literal({
    required this.data,
    required this.fieldName,
    required this.nodeView,
  });

  @override
  final String fieldName;

  @override
  final NodeID<NodeView> nodeView;

  @override
  final T data;

  @override
  Cursor<Object>? build(Reader reader, Ctx ctx) {
    return ctx.state.getNode(nodeView).fields[fieldName].whenPresent.cast<Literal>().data;
  }

  @override
  GetCursor<String> name(Reader reader, Ctx ctx) => const GetCursor('Literal');
}

@immutable
@reify
class Text with _TextMixin {
  @override
  final Vec<TextElement> elements;

  Text([this.elements = const Vec([PlainText('')])]);
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
