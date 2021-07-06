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
  runApp(MyApp());
}

@reader_widget
Widget myApp() {
  return CursorWidget(
    create: () => model.State(),
    builder: (_, reader, Cursor<model.State> state) => KeyPressedProvider(
      child: MaterialApp(
        title: 'knose',
        shortcuts: shortcuts,
        actions: actions,
        theme: theme(Colors.grey, Brightness.light),
        home: MainScaffold(state, null),
      ),
    ),
  );
}
