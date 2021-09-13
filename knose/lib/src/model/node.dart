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
  required Cursor<State> state,
  required Dict<String, Cursor<Object>> fields,
  flutter.FocusNode? defaultFocus,
});

@immutable
abstract class NodeBuilder {
  const NodeBuilder();

  NodeBuilderFn get build;
  bool canBuild(Ctx ctx) => true;
  Dict<String, Datum> makeFields(Cursor<State> state);
  NodeID<NodeView> addView(Cursor<State> state) {
    return state.addNode(NodeView(nodeBuilder: this, fields: makeFields(state)));
  }
}

@immutable
abstract class TopLevelNodeBuilder extends NodeBuilder {
  const TopLevelNodeBuilder();

  Cursor<String> title({
    required Ctx ctx,
    required Cursor<State> state,
    required Dict<String, Cursor<Object>> fields,
  });
}

@immutable
@reify
class NodeView with _NodeViewMixin implements Node {
  @override
  final NodeID<NodeView> id;

  @override
  final Dict<String, Datum> fields;

  @override
  final NodeBuilder nodeBuilder;

  NodeView({
    NodeID<NodeView>? id,
    required this.nodeBuilder,
    required this.fields,
  }) : id = id ?? NodeID<NodeView>();
}

@immutable
@reify
class Field<T extends Object> with _FieldMixin {
  @override
  final String name;

  @override
  final Datum data;

  Field({required this.name, required this.data});
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
  DataBuilder get dataBuilder;
}

extension DatumImpl on Cursor<Datum> {
  GetCursor<String> name(Reader reader) => dataBuilder.read(reader).name(this);
  Cursor<Object> build(Reader reader) => dataBuilder.read(reader).build(this);
}

abstract class DataBuilder {
  const DataBuilder();

  GetCursor<String> name(Cursor<Datum> datum);
  Cursor<Object> build(Cursor<Datum> datum);
}

@immutable
@reify
class Literal<T> extends Datum with _LiteralMixin<T> {
  const Literal(this.data);

  @override
  final T data;

  @override
  DataBuilder get dataBuilder => _LiteralBuilder();
}

class _LiteralBuilder extends DataBuilder {
  _LiteralBuilder();

  @override
  Cursor<Object> build(Cursor<Datum> datum) => datum.cast<Literal<Object>>().data;

  @override
  GetCursor<String> name(Cursor<Datum> datum) => const GetCursor('Literal');
}

@immutable
@reify
class Text with _TextMixin implements Node {
  @override
  final NodeID<Text> id;

  @override
  final Vec<TextElement> elements;

  Text([this.elements = const Vec([PlainText('')]), NodeID<Text>? id]) : id = id ?? NodeID();
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
