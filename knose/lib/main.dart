import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/pal.dart';
import 'package:knose/theme.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/shortcuts.dart';

part 'main.g.dart';

void main() {
  runApp(const MyApp());
}

@reader
Widget myApp() {
  return CursorWidget(
    ctx: Ctx.empty,
    create: () => model.baseDB,
    builder: (_, ctx, Cursor<DB> db) => KeyPressedProvider(
      child: MaterialApp(
        title: 'knose',
        shortcuts: shortcuts,
        actions: actions,
        theme: theme(Colors.grey, Brightness.light),
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return generateSearchRoute(ctx.withDB(db));
          }

          final arguments = settings.arguments;
          if (arguments is model.Route) {
            return arguments.cases(
              widgetRoute: (widget) => generateWidgetRoute(widget.ctx ?? ctx.withDB(db), widget.id),
              searchRoute: (_) => generateSearchRoute(ctx.withDB(db)),
            );
          }
        },
      ),
    ),
  );
}
