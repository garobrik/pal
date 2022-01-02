import 'package:ctx/ctx.dart';
import 'package:knose/pal.dart' as pal;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';

part 'route.g.dart';

@ReifiedLens(cases: [SearchRoute, WidgetRoute])
class Route with _RouteMixin {
  const Route();
}

@reify
class SearchRoute extends Route with _SearchRouteMixin {
  const SearchRoute();
}

@reify
class WidgetRoute extends Route with _WidgetRouteMixin {
  @override
  final pal.ID id;
  @override
  final Ctx? ctx;

  const WidgetRoute(this.id, {this.ctx});
}
