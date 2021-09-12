import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';

part 'table.g.dart';

@immutable
class TableBuilder extends model.TopLevelNodeBuilder {
  const TableBuilder();

  @override
  model.NodeBuilderFn get build => MainTableWidget.tearoff;

  @override
  Dict<String, model.Datum> makeFields(Cursor<model.State> state) {
    return Dict({'table': model.Literal<model.Table>(model.Table.newDefault())});
  }

  @override
  Cursor<String> title({
    required model.Ctx ctx,
    required Cursor<model.State> state,
    required Dict<String, Cursor<Object>> fields,
  }) {
    return fields['table'].unwrap!.cast<model.Table>().title;
  }
}

@reader_widget
Widget _mainTableWidget(
  BuildContext context,
  Reader reader, {
  required model.Ctx ctx,
  required Cursor<model.State> state,
  required Dict<String, Cursor<Object>> fields,
  FocusNode? defaultFocus,
}) {
  final table = fields['table'].unwrap!.cast<model.Table>();

  return Scrollable2D(
    child: Container(
      padding: const EdgeInsets.all(20),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRectNotBottom(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).canvasColor,
                  boxShadow: const [BoxShadow(blurRadius: 4)],
                ),
                child: TableHeader(table),
              ),
            ),
            TableRows(table),
            ElevatedButton(
              onPressed: () => table.addRow(),
              focusNode: defaultFocus,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: const [Icon(Icons.add), Text('New row')],
              ),
            )
          ],
        ),
      ),
    ),
  );
}
