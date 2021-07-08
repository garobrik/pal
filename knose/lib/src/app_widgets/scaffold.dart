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
  Reader reader,
  Cursor<model.State> state,
  model.PageOrTableID? displayed,
) {
  return KnoseActions(
    child: Scaffold(
      appBar: AppBar(
        title: displayed == null
            ? Text('knose')
            : IntrinsicWidth(
                child: BoundTextFormField(
                  displayed.cases(
                    tableID: (tableID) => state.tables[tableID].nonnull.title,
                    pageID: (pageID) => state.pages[pageID].nonnull.title,
                  ),
                  style: Theme.of(context).textTheme.headline6,
                  decoration: InputDecoration(hintText: 'table title'),
                ),
              ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black38)],
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        ),
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
                final tableID = state.addTable(model.Table.newDefault());
                final route = MaterialPageRoute<Null>(
                  builder: (context) => MainScaffold(state, tableID),
                );

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
                showDialog<Null>(
                  barrierColor: Colors.black12,
                  context: context,
                  builder: (_) => SearchDialog(state),
                );
              },
            ),
          ],
        ),
      ),
      body: InheritedStack(
        child: displayed?.cases(
              tableID: (tableID) => MainTableWidget(state.tables[tableID].nonnull),
              pageID: (pageID) => MainPageWidget(state.pages[pageID].nonnull),
            ) ??
            Center(child: Text('Nothing selected!')),
      ),
    ),
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
