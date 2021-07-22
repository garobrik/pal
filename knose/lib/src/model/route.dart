import 'package:knose/model.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';

part 'route.g.dart';

@ReifiedLens(cases: [TableRoute, PageRoute, SearchRoute])
class Route with _RouteMixin {
  const Route();
}

@reify
class TableRoute extends Route with _TableRouteMixin {
  @override
  final TableID id;

  const TableRoute(this.id);
}

@reify
class PageRoute extends Route with _PageRouteMixin {
  @override
  final PageID id;

  const PageRoute(this.id);
}

@reify
class SearchRoute extends Route with _SearchRouteMixin {
  const SearchRoute();
}
