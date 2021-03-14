import 'package:example/model/table.dart' as model;
import 'package:example/widgets/table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_portal/flutter_portal.dart';

part 'main.g.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Portal(
      child: MaterialApp(
        title: 'Flutter Demo',
        home: Theme(
          data: Theme.of(context).copyWith(
            scrollbarTheme: ScrollbarTheme.of(context).copyWith(
              isAlwaysShown: true,
            ),
          ),
          child: CursorWidget<AppState>(
            create: () => AppState(null, Vec()),
            builder: (_, state) => Scaffold(
              appBar: AppBar(
                title: Text('knose'),
              ),
              body: state.selectedTable.get == null
                  ? SizedBox.shrink()
                  : Center(
                      child: TableWidget(
                        state.tables[state.selectedTable.get!],
                        key: ValueKey(state.selectedTable.get),
                      ),
                    ),
              drawer: Drawer(
                child: Builder(
                  builder: (context) => ListView(
                    children: [
                      for (final indexedTable in state.tables.indexedValues)
                        TextButton(
                          onPressed: () => state.selectedTable.set(indexedTable.index),
                          child: Text(indexedTable.value.title.get),
                        ),
                      TextButton(
                        onPressed: () {
                          state.tables.add(
                            model.Table(
                              title: 'table ${state.tables.length.get + 1}',
                              columns: Vec([
                                model.StringColumn(title: 'name'),
                                model.BooleanColumn(title: 'done'),
                              ]),
                            ),
                          );
                          state.selectedTable.set(state.tables.length.get - 1);
                          Navigator.pop(context);
                        },
                        child: Text('Add Table'),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@reify
class AppState {
  final int? selectedTable;
  final Vec<model.Table> tables;
  AppState(this.selectedTable, this.tables);
}
