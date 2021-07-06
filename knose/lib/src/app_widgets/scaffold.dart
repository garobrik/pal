import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/infra_widgets.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/shortcuts.dart';

part 'scaffold.g.dart';

@reader_widget
Widget _mainScaffold(
  BuildContext context,
  Reader reader,
  Cursor<model.State> state,
  model.PageOrTableID? displayed,
) {
  return KnoseActions(
    child: Scaffold(
      appBar: AppBar(
        title: displayed == null
            ? Text('knose')
            : BoundTextFormField(
                displayed.cases(
                  tableID: (tableID) => state.tables[tableID].nonnull.title,
                  pageID: (pageID) => state.pages[pageID].nonnull.title,
                ),
                style: Theme.of(context).textTheme.headline6,
              ),
      ),
      bottomNavigationBar: Material(
        elevation: 10.0,
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            BottomButton(
              text: 'New page',
              icon: Icons.post_add,
              onPressed: () {
                final pageID = state.addPage(model.Page(title: 'Untitled page'));
                final route =
                    MaterialPageRoute<Null>(builder: (context) => MainScaffold(state, pageID));

                if (displayed == null) {
                  Navigator.pushReplacement(context, route);
                } else {
                  Navigator.push(context, route);
                }
              },
            ),
            BottomButton(
              text: 'New table',
              icon: Icons.playlist_add,
              onPressed: () {
                final tableID = state.addTable(model.Table(title: 'Untitled table'));
                final route =
                    MaterialPageRoute<Null>(builder: (context) => MainScaffold(state, tableID));

                if (displayed == null) {
                  Navigator.pushReplacement(context, route);
                } else {
                  Navigator.push(context, route);
                }
              },
            ),
            BottomButton(
              text: 'Search',
              icon: Icons.search,
              onPressed: () {
                showDialog<Null>(context: context, builder: (_) => SearchDialog(state));
              },
            ),
          ],
        ),
      ),
      body: displayed?.cases(
            tableID: (tableID) => MainTableWidget(state.tables[tableID].nonnull),
            pageID: (pageID) => MainPageWidget(state.pages[pageID].nonnull),
          ) ??
          Center(child: Text('Nothing selected!')),
    ),
  );
}

@reader_widget
Widget _bottomButton({
  required void Function() onPressed,
  required IconData icon,
  required String text,
}) {
  return TextButton(
    onPressed: onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          Text(text),
        ],
      ),
    ),
  );
}

@reader_widget
Widget _scrollable2D(BuildContext context) {
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
