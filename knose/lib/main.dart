import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/theme.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/shortcuts.dart';

part 'main.g.dart';

void main() {
  runApp(const MyApp());
}

@reader_widget
Widget myApp() {
  return CursorWidget(
    create: () => const model.State(),
    builder: (_, reader, Cursor<model.State> state) => KeyPressedProvider(
      child: MaterialApp(
        title: 'knose',
        shortcuts: shortcuts,
        actions: actions,
        theme: theme(Colors.grey, Brightness.light),
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return generateSearchRoute(model.Ctx(state));
          }

          final arguments = settings.arguments;
          if (arguments is model.Route) {
            return arguments.cases(
              nodeRoute: (node) => generateNodeRoute(model.Ctx(state), node.id),
              tableRoute: (_) => null,
              pageRoute: (_) => null,
              searchRoute: (_) => generateSearchRoute(model.Ctx(state)),
            );
          }
        },
      ),
    ),
  );
}
