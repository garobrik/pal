import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/key_pressed_provider.dart';

part 'main_scaffold.g.dart';

@reader_widget
Widget mainScaffold(
  Reader reader,
  Cursor<model.State> state,
  model.PageOrTableID? displayed,
) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        displayed?.cases(
              tableID: (tableID) => state.tables[tableID].nonnull.title.read(reader),
              pageID: (pageID) => state.pages[pageID].nonnull.title.read(reader),
            ) ??
            'knose',
      ),
    ),
    bottomNavigationBar: Material(
      elevation: 10.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(
            onPressed: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search),
                  Text('Search'),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add),
                  Text('New page'),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    body: displayed?.cases(
          tableID: (tableID) => MainTableWidget(state.tables[tableID].nonnull),
          pageID: (pageID) => MainPageWidget(state.tables[pageID].nonnull),
        ) ??
        Center(child: Text('Nothing selected!')),
  );
}

@reader_widget
Widget scrollable2D(BuildContext context) {
  final transformationController = useTransformationController();

  return Listener(
    onPointerSignal: (signal) {
      final shiftPressed = isKeyPressed(context, LogicalKeyboardKey.shiftLeft) ||
          isKeyPressed(context, LogicalKeyboardKey.shiftRight) ||
          isKeyPressed(context, LogicalKeyboardKey.shift);

      if (signal is PointerScrollEvent) {
        transformationController.value = transformationController.value.clone()
          ..translate(
            shiftPressed ? signal.scrollDelta.dy : signal.scrollDelta.dx,
            shiftPressed ? 0.0 : signal.scrollDelta.dy,
          );
      }
    },
    child: InteractiveViewer(
      transformationController: transformationController,
      clipBehavior: Clip.hardEdge,
      scaleEnabled: false,
      constrained: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final _ in range(10))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final _ in range(10))
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(border: Border.all()),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}
