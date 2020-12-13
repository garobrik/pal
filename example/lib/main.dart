// @dart=2.9
import 'package:example/model/table.dart' hide Table, Column;
import 'package:example/model/table.dart' as model;
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:functional/functional.dart';
import 'package:provider/provider.dart';
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
          body: Consumer<ListenableState<model.Table>>(
            builder: (_, v, __) => Center(child: TableWidget(v.cursor)),
          ),
        ),
        create: (_) => ListenableState(model.Table.from(columns: [
          for (int column = 0; column < 5; column++)
            StringColumn.from(values: List.generate(5, (i) => 'Row $i'))
        ])),
      ),
    );
  }
}

class TableWidget extends StatelessWidget {
  final Cursor<model.Table> table;
  TableWidget(this.table);

  @override
  Widget build(BuildContext context) {
    ScrollController _scrollController =
        PrimaryScrollController.of(context) ?? ScrollController();

    int width = 0;
    for (int column = 0; column < table.columns.length.get(); column++) {
      width += table.columns[column].width.get();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width.toDouble()),
        child: CustomScrollView(
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          shrinkWrap: true,
          slivers: [
            SliverList(delegate: SliverChildListDelegate([buildHeader()])),
            table.length.build(
              (_, length) => ReorderableSliverList(
                onReorder: (a, b) {
                  table.columns.forEach((column) {
                    final dynamic bVal = column.values[b].get();
                    column.values[b].set(column.values[a].get());
                    column.values[a].set(bVal);
                  });
                },
                delegate: ReorderableSliverChildBuilderDelegate(
                  (_, i) => buildRow(i),
                  childCount: length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeader() {
    return table.columns.length.build((_, length) => ReorderableRow(
        onReorder: (a, b) {
          final aVal = table.columns[a].get();
          table.columns[a].set(table.columns[b].get());
          table.columns[b].set(aVal);
        },
        children: List.generate(
          length,
          (columnIndex) => table.columns[columnIndex].width.build(
            (_, width) => ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: width.toDouble(),
                maxWidth: width.toDouble(),
              ),
              child: Text('header'),
            ),
            key: UniqueKey(),
          ),
        )));
  }

  Widget buildRow(int rowIndex) {
    return table.columns.length.build(
      (_, length) => Row(
        children: List.generate(
          length,
          (columnIndex) {
            final column = table.columns[columnIndex];
            return column.width.build(
              (_, width) => ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: width.toDouble(),
                  maxWidth: width.toDouble(),
                ),
                child: column.values[rowIndex].build(
                  (_, dynamic s) => Text(s.toString()),
                ),
              ),
            );
          },
        ),
      ),
      key: ValueKey(rowIndex),
    );
  }
}
