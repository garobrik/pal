import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'page.g.dart';

Route<Null> generatePageRoute(Cursor<model.State> state, model.PageID pageID) {
  final page = state.getPage(pageID);
  return MaterialPageRoute(
    settings: RouteSettings(name: page.title.read(null), arguments: model.PageRoute(pageID)),
    builder: (_) => MainScaffold(
      title: EditableScaffoldTitle(page.title),
      state: state,
      body: MainPageWidget(page),
      replaceRouteOnPush: false,
    ),
  );
}

@reader_widget
Widget _mainPageWidget(Reader reader, BuildContext context, Cursor<model.Page> page) {
  return Container(
    color: Theme.of(context).colorScheme.background,
    constraints: BoxConstraints.expand(),
    child: Container(
      // margin: EdgeInsets.all(15),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black38)],
      ),
      child: Column(
        children: [
          for (final element in page.elements.values(reader)) PageElement(element),
        ],
      ),
    ),
  );
}

@reader_widget
Widget _pageElement(Reader reader, Cursor<model.PageElement> element) {
  return element.cases(
    reader,
    header: (header) => PageHeader(header),
    paragraph: (paragraph) => TextWidget(paragraph.text),
    pageList: (list) => Container(),
  );
}

@reader_widget
Widget _pageHeader(Reader reader, BuildContext context, Cursor<model.Header> header) {
  final textTheme = Theme.of(context).textTheme;

  return BoundTextFormField(
    header.text,
    style: () {
      switch (header.level.read(reader)) {
        case 1:
          return textTheme.headline1!;
        case 2:
          return textTheme.headline2!;
        case 3:
          return textTheme.headline3!;
        default:
          return textTheme.headline4!;
      }
    }().copyWith(decoration: TextDecoration.underline),
  );
}
