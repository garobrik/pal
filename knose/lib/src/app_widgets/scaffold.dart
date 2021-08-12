import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/infra_widgets.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/shortcuts.dart';
import 'package:knose/src/infra_widgets/dropdown.dart';

part 'scaffold.g.dart';

@reader_widget
Widget _mainScaffold(
  BuildContext context,
  Reader reader, {
  required Cursor<model.State> state,
  required Widget body,
  required bool replaceRouteOnPush,
  Widget? title,
}) {
  return KnoseActions(
    child: Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              title: title,
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black38)],
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            BottomButton(
              text: 'New page',
              icon: Icons.post_add,
              onPressed: () {
                final nodeViewID = state.addNode(
                  model.NodeView.from(
                    builder: const PageBuilder(),
                    nodeID: state.addNode(
                      model.Page(
                        title: 'Untitled page',
                        nodeViews: Vec([
                          state.addNode(
                            model.NodeView.from(
                              builder: const TextBuilder(),
                              nodeID: state.addNode(
                                model.Text(),
                              ),
                            ),
                          )
                        ]),
                      ),
                    ),
                  ),
                );

                if (replaceRouteOnPush) {
                  Navigator.pushReplacementNamed(context, '',
                      arguments: model.NodeRoute(nodeViewID));
                } else {
                  Navigator.pushNamed(context, '', arguments: model.NodeRoute(nodeViewID));
                }
              },
            ),
            BottomButton(
              text: 'New table',
              icon: Icons.playlist_add,
              onPressed: () {
                final nodeViewID = state.addNode(
                  model.NodeView.from(
                    builder: const TableBuilder(),
                    nodeID: state.addNode(model.Table.newDefault()),
                  ),
                );

                if (replaceRouteOnPush) {
                  Navigator.pushReplacementNamed(
                    context,
                    '',
                    arguments: model.NodeRoute(nodeViewID),
                  );
                } else {
                  Navigator.pushNamed(context, '', arguments: model.NodeRoute(nodeViewID));
                }
              },
            ),
            BottomButton(
              text: 'Search',
              icon: Icons.search,
              onPressed: () {
                if (replaceRouteOnPush) {
                  Navigator.pushReplacementNamed(context, '', arguments: model.SearchRoute());
                } else {
                  Navigator.pushNamed(context, '', arguments: model.SearchRoute());
                }
              },
            ),
          ],
        ),
      ),
      body: InheritedStack(child: body),
    ),
  );
}

@reader_widget
Widget _editableScaffoldTitle(BuildContext context, Cursor<String> title) {
  return IntrinsicWidth(
    child: BoundTextFormField(
      title,
      style: Theme.of(context).textTheme.headline6,
      decoration: InputDecoration(hintText: 'table title'),
    ),
  );
}

@reader_widget
Widget _scaffoldTitle(Reader reader, BuildContext context, GetCursor<String> title) {
  return Text(
    title.read(reader),
    style: Theme.of(context).textTheme.headline6,
  );
}

@reader_widget
Widget _bottomButton({
  required void Function() onPressed,
  required IconData icon,
  required String text,
}) {
  return ElevatedButton(
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
