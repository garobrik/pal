import 'package:meta/meta.dart';

import 'package:knose/model.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'page.g.dart';

@immutable
@reify
class Page with _PageMixin implements TitledNode {
  @override
  final NodeID<Page> id;
  @override
  final String title;
  @override
  final Vec<NodeID<NodeView>> nodeViews;

  Page({
    NodeID<Page>? id,
    this.title = '',
    this.nodeViews = const Vec(),
  }) : this.id = id ?? NodeID<Page>();

  @override
  Page mut_title(String title) => copyWith(title: title);
}

@immutable
@reify
class Header with _HeaderMixin {
  @override
  final String text;
  @override
  final int level;

  const Header(this.text, [this.level = 1]);
}
