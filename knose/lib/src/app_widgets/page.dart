import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/model.dart' as model;

part 'page.g.dart';

Route<Null> generatePageRoute(Cursor<model.State> state, model.PageID pageID) {
  final page = state.pages[pageID].nonnull;
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
Widget _mainPageWidget(BuildContext context, Cursor<model.Page> page) {
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
      child: BoundTextFormField(
        page.contents,
        decoration: InputDecoration(filled: false, focusedBorder: InputBorder.none),
        autofocus: true,
        maxLines: null,
      ),
    ),
  );
}
