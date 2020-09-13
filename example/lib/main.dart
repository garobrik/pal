import 'package:example/model/table.dart' hide Table, Column;
import 'package:example/model/table.dart' as Model;
import 'package:flutter/material.dart' hide Table;
import 'package:functional/functional.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:reorderables/reorderables.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Provider(
        child: Center(
            child: Consumer(
          builder: (_, v, __) => Center(child: TableWidget(v.table)),
        )),
        create: (_) => ListenableState(Model.Table.from(columns: [
          StringColumn.from(values: ['test', 'row'])
        ])),
      ),
    );
  }
}

class TableWidget extends StatelessWidget {
  final Zoom<Cursor, Model.Table> table;
  TableWidget(this.table);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      buildHeader(),
      table.length.build((length) => ReorderableSliverList(
            onReorder: (a, b) {
              table.columns.forEach((column) {
                column.values[a].set(column.values[b].get(() {}));
                column.values[b].set(column.values[a].get(() {}));
              });
            },
            delegate: ReorderableSliverChildBuilderDelegate(
              (_, i) => buildRow(i),
              childCount: length,
            ),
          )),
    ]);
  }

  Widget buildHeader() {
    return table.columns.length.build((length) => ReorderableSliverList(
          onReorder: (a, b) {
            table.columns[a].set(table.columns[b].get(() {}));
            table.columns[b].set(table.columns[a].get(() {}));
          },
          delegate: ReorderableSliverChildBuilderDelegate(
            (_, i) => Text('header'),
            childCount: length,
          ),
        ));
  }

  Widget buildRow(int index) {
    return table.columns.length.build((length) => ReorderableSliverList(
        onReorder: (a, b) {
          table.columns[a].set(table.columns[b].get(() {}));
          table.columns[b].set(table.columns[a].get(() {}));
        },
        delegate: ReorderableSliverChildBuilderDelegate(
          (_, i) => Text(table.columns[i].values[index].get((){})),
          childCount: length,
        ),
    ));
  }
}
