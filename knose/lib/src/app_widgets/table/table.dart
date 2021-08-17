import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';

part 'table.g.dart';

@immutable
@reify
class TableBuilder with model.TypedNodeBuilder<model.Table>, _TableBuilderMixin {
  const TableBuilder();

  @override
  model.NodeBuilderFn<model.Table> get buildTyped => MainTableWidget.tearoff;
}

@reader_widget
Widget _mainTableWidget(BuildContext context, Reader reader, Cursor<model.State> state, Cursor<model.Table> table) {
  return Scrollable2D(
    child: Container(
      padding: EdgeInsets.all(20),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRectNotBottom(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).canvasColor,
                  boxShadow: [BoxShadow(blurRadius: 4)],
                ),
                child: TableHeader(table),
              ),
            ),
            TableRows(table),
            ElevatedButton(
              onPressed: () => table.addRow(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [Icon(Icons.add), Text('New row')],
              ),
            )
          ],
        ),
      ),
    ),
  );
}
