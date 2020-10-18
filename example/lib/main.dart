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
      home: Provider(
        child: Scaffold(
          body: Consumer<ListenableState<Model.Table>>(
            builder: (_, v, __) => Center(child: TableWidget(v.cursor)),
          ),
        ),
        create: (_) => ListenableState(Model.Table.from(columns: [
              StringColumn.from(values: List.generate(50, (i) => "Row $i"))
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
    ScrollController _scrollController =
        PrimaryScrollController.of(context) ?? ScrollController();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500),
        child: CustomScrollView(
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          shrinkWrap: true,
          slivers: [
            SliverList(delegate: SliverChildListDelegate([buildHeader()])),
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
          ],
        ),
      ),
    );
  }

  Widget buildHeader() {
    return table.columns.length.build((length) => Row(
      // onReorder: (a, b) {
      //   table.columns[a].set(table.columns[b].get(() {}));
      //   table.columns[b].set(table.columns[a].get(() {}));
      // },
      children: List.generate(
        length,
        (columnIndex) => Text('header', key: ValueKey(columnIndex)),
      ),
    ));
  }

  Widget buildRow(int rowIndex) {
    return table.columns.length.build(
      (length) => Row(
        children: List.generate(
          length,
          (columnIndex) => table.columns[columnIndex].values[rowIndex].build(
            (s) => Text(s),
          ),
        ),
      ),
      key: ValueKey(rowIndex),
    );
  }
}
