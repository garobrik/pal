// @dart=2.9
import 'package:example/model/table.dart' hide Table, Column;
import 'package:example/model/table.dart' as model;
import 'package:flutter/material.dart' hide Table;
import 'package:flutter/rendering.dart';
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
            builder: (_, v, __) => Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(5),
              child: TableWidget(v.cursor),
            ),
          ),
        ),
        create: (_) => ListenableState(model.Table.from(columns: [
          for (int column = 0; column < 10; column++)
            StringColumn.from(
              values: List.generate(40, (row) => 'Row $row, Column $column'),
              title: 'Column $column',
            )
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
    ScrollController horizontalScrollController = ScrollController();
    ScrollController scrollController = ScrollController();

    double width = 0;
    for (int column = 0; column < table.columns.length.get(); column++) {
      width += table.columns[column].width.get();
    }
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalScrollController,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: CustomScrollView(
            controller: scrollController,
            scrollDirection: Axis.vertical,
            // shrinkWrap: true, // want to do this, but it breaks the persistent header for some reason :/
            slivers: [
              SliverPersistentHeader(
                delegate: PersistentHeaderDelegate(buildHeader(), height: 30.0),
                pinned: true,
              ),
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
      ),
    );
  }

  Widget buildHeader() {
    ScrollController scrollController = ScrollController();

    return table.columns.length.build(
      (context, length) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(bottom: BorderSide()),
        ),
        child: ReorderableRow(
          scrollController: scrollController,
          onReorder: (a, b) {
            final aVal = table.columns[a].get();
            table.columns[a].set(table.columns[b].get());
            table.columns[b].set(aVal);
          },
          children: List.generate(
            length,
            (columnIndex) {
              final column = table.columns[columnIndex];
              return column.width.build(
                (context, width) => Container(
                  constraints: BoxConstraints(
                    minWidth: width,
                    maxWidth: width,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      left: columnIndex == 0 ? BorderSide.none : BorderSide(),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  height: double.infinity,
                  padding: EdgeInsets.all(2),
                  child: column.title.build((_, title) => Text(title)),
                ),
                key: UniqueKey(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildRow(int rowIndex) {
    return table.columns.length.build(
      (_, length) => Row(
        children: List.generate(
          length,
          (columnIndex) {
            final column = table.columns[columnIndex];
            return column.width.build(
              (context, width) => Container(
                constraints: BoxConstraints(
                  minWidth: width,
                  maxWidth: width,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: rowIndex == 0 ? BorderSide.none : BorderSide(),
                    left: columnIndex == 0 ? BorderSide.none : BorderSide(),
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: column.values[rowIndex].build(
                  (_, dynamic s) => Text(s.toString()),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  PersistentHeaderDelegate(this.child, {this.height});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return AnimatedContainer(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
        boxShadow: [
          if (shrinkOffset > 0)
            BoxShadow(
              blurRadius: 3,
              spreadRadius: 0,
              offset: Offset(0, 0),
              color: Colors.grey,
            )
        ],
      ),
      duration: Duration(milliseconds: 100),
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}
