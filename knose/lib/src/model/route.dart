import 'package:knose/model.dart' hide List;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';

part 'route.g.dart';

@ReifiedLens(cases: [TableRoute, PageRoute, SearchRoute, NodeRoute])
class Route with _RouteMixin {
  const Route();
}

@reify
class TableRoute extends Route with _TableRouteMixin {
  @override
  final NodeID<Table> id;

  const TableRoute(this.id);
}

@reify
class PageRoute extends Route with _PageRouteMixin {
  @override
  final NodeID<Page> id;

  const PageRoute(this.id);
}

@reify
class SearchRoute extends Route with _SearchRouteMixin {
  const SearchRoute();
}


@reify
class NodeRoute extends Route with _NodeRouteMixin {
  @override
  final NodeID<NodeView> id;

  const NodeRoute(this.id);
}
