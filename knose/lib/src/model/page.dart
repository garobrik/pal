import 'package:meta/meta.dart';

import 'package:knose/model.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'page.g.dart';

class PageID extends UUID<PageID> {}

@immutable
@reify
class Page with _PageMixin {
  @override
  final PageID id;
  @override
  final String title;
  @override
  final Vec<PageElement> elements;

  Page({
    PageID? id,
    this.title = '',
    this.elements = const Vec([Paragraph()]),
  }) : this.id = id ?? PageID();
}

@immutable
@ReifiedLens(cases: [Header, Paragraph, PageList])
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
class Paragraph extends PageElement with _ParagraphMixin {
  @override
  final Text text;

  const Paragraph([this.text = const Text()]);
}

@immutable
@reify
class PageList with _PageListMixin {
  @override
  final Vec<NodeID> nodes;

  const PageList([this.nodes = const Vec()]);
}
