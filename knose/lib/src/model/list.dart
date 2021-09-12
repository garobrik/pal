import 'package:meta/meta.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart';

part 'list.g.dart';

@immutable
@reify
class List with _ListMixin implements Node {
  @override
  final NodeID<List> id;
  @override
  final Vec<NodeID<NodeView>> nodeViews;

  List({
    NodeID<List>? id,
    this.nodeViews = const Vec(),
  }) : this.id = id ?? NodeID<List>();
}
