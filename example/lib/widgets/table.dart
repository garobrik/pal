import 'package:example/widgets/cross_axis_protoheader.dart';
import 'package:example/widgets/table_header.dart';
import 'package:example/widgets/table_row.dart';
import 'package:reorderables/reorderables.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import '../model/table.dart' as model;
import 'package:flutter/material.dart' hide TableRow;

part 'table.g.dart';

@reader_widget
Widget _tableWidget(Reader reader, Cursor<model.Table> table) {
  return Padding(
    padding: EdgeInsets.all(20),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(),
        clipBehavior: Clip.none,
        padding: EdgeInsets.only(bottom: 15),
        child: CrossAxisProtoheader(
          header: Container(
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
          body: CustomScrollView(
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            slivers: [
              ReorderableSliverList(
                onReorder: (old, nu) {
                  table.rowIDs.insert(nu < old ? nu : nu + 1, table.rowIDs[old].read(reader));
                  table.rowIDs.remove(nu < old ? old + 1 : old);
                },
                delegate: ReorderableSliverChildBuilderDelegate(
                  (_, i) => TableRow(
                    table,
                    table.rowIDs[i],
                    key: ValueKey(table.rowIDs[i].read(reader)),
                  ),
                  childCount: table.length.read(reader),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide()),
                    ),
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => table.addRow(),
                      child: Container(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.add), Text('New row')],
                        ),
                      ),
                    ),
                  ),
                ]),
              )
            ],
          ),
        ),
      ),
    ),
  );
}
