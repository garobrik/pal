import 'package:meta/meta.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart';

part 'state.g.dart';

@immutable
@reify
class State with _StateMixin {
  @override
  final Dict<NodeID, Object> nodes;

  const State({
    this.nodes = const Dict(),
  });
}

extension StateReads on Cursor<State> {
  Cursor<N> getNode<N extends Node>(NodeID<N> id) {
    return nodes[id].whenPresent.cast<N>();
  }
}

extension StateMutations on Cursor<State> {
  NodeID<N> addNode<N extends Node>(N node) {
    nodes[node.id] = Optional(node);
    return node.id as NodeID<N>;
  }
}
