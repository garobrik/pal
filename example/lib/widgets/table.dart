import 'package:example/widgets/cross_axis_protoheader.dart';
import 'package:example/widgets/table_header.dart';
import 'package:example/widgets/table_row.dart';
import 'package:reorderables/reorderables.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import '../model/table.dart' as model;
import 'package:flutter/material.dart' hide TableRow;

part 'table.g.dart';

@bound_widget
Widget _tableWidget(Cursor<model.Table> table) {
  final horizontalController = useScrollController();

  return Padding(
    padding: EdgeInsets.all(20),
    child: Scrollbar(
      controller: horizontalController,
      child: SingleChildScrollView(
        controller: horizontalController,
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(),
          clipBehavior: Clip.none,
          padding: EdgeInsets.only(bottom: 15),
          child: CrossAxisProtoheader(
            header: (_) => Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    blurRadius: 6,
                    color: Colors.grey,
                  ),
                ],
              ),
              child: TableHeader(table),
            ),
            body: (scrollController) => Scrollbar(
              controller: scrollController,
              child: CustomScrollView(
                controller: scrollController,
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                slivers: [
                  ReorderableSliverList(
                    onReorder: (old, nu) {
                      table.rowIDs.insert(nu < old ? nu : nu + 1, table.rowIDs[old].get);
                      table.rowIDs.remove(nu < old ? old + 1 : old);
                    },
                    delegate: ReorderableSliverChildBuilderDelegate(
                      (_, i) => TableRow(
                        table,
                        table.rowIDs[i],
                        key: ValueKey(table.rowIDs[i].get),
                      ),
                      childCount: table.length.get,
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide()),
                        ),
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () => table.addRow(),
                        ),
                      ),
                    ]),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
