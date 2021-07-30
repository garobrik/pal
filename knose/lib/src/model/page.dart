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
@ReifiedLens(cases: [Header, PageList])
class PageElement with _PageElementMixin {
  const PageElement();
}

@immutable
@reify
class Header extends PageElement with _HeaderMixin {
  @override
  final String text;
  @override
  final int level;

  const Header(this.text, [this.level = 1]);
}

@immutable
@reify
class PageList with _PageListMixin {
  @override
  final Vec<NodeID> nodes;

  const PageList([this.nodes = const Vec()]);
}
