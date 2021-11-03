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
  Dict<String, model.Datum> makeFields(
    Cursor<model.State> state,
    model.NodeID<model.NodeView> nodeView,
  ) {
    final table = model.Table.newDefault();
    state.addNode(table);
    return Dict({
      'table': model.Literal(
        // TODO: fix type
        typeData: model.booleanType,
        data: table.id,
        nodeView: nodeView,
        fieldName: 'table',
      )
    });
  }

  @override
  String title({
    required model.Ctx ctx,
    required Dict<String, Cursor<Object>> fields,
    required Reader reader,
  }) {
    final tableID = fields['table'].unwrap!.cast<model.NodeID<model.Table>>().read(reader);
    return ctx.state.getNode(tableID).title.read(reader);
  }
}

@reader_widget
Widget _mainTableWidget(
  BuildContext context,
  Reader reader, {
  required model.Ctx ctx,
  required Dict<String, Cursor<Object>> fields,
  FocusNode? defaultFocus,
}) {
  final tableID = fields['table'].unwrap!.cast<model.NodeID<model.Table>>().read(reader);
  final table = ctx.state.getNode(tableID);

  return Container(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const OpenRowButton(),
            Container(
              padding: const EdgeInsetsDirectional.only(bottom: 20),
              child: IntrinsicWidth(
                child: BoundTextFormField(
                  table.title,
                  style: Theme.of(context).textTheme.headline6,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const OpenRowButton(),
            TableConfig(ctx: ctx, table: table),
          ],
        ),
        Expanded(
          child: Scrollable2D(
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const OpenRowButton(),
                      ClipRectNotBottom(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).canvasColor,
                            boxShadow: const [BoxShadow(blurRadius: 4)],
                            border: const Border(top: BorderSide()),
                          ),
                          child: TableHeader(table),
                        ),
                      ),
                    ],
                  ),
                  TableRows(ctx: ctx, table: table),
                  Row(
                    children: [
                      const OpenRowButton(),
                      ElevatedButton(
                        onPressed: () => table.addRow(),
                        focusNode: defaultFocus,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: const [Icon(Icons.add), Text('New row')],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
