import 'package:example/widgets/cross_axis_protoheader.dart';
import 'package:reorderables/reorderables.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import '../model/table.dart' as model;
import 'primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

@bound_widget
Widget _tableHeader(BuildContext context, Cursor<model.Table> table) {
  return FocusTraversalGroup(
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide()),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            child: BoundTextField(
              table.title,
              style: Theme.of(context).textTheme.headline3,
              decoration: _tableCellBoundTextDecoration,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                // onReorder: (oldIdx, newIdx) {
                //   table.columns.insert(newIdx, table.columns[oldIdx].get);
                //   table.columns.remove(newIdx < oldIdx ? oldIdx + 1 : oldIdx);
                // },
                children: [
                  for (final indexedColumnID in table.columnIDs.indexedValues)
                    TableHeaderCell(
                      key: ValueKey(indexedColumnID.value.get),
                      table: table,
                      column: table.columns[indexedColumnID.value.get],
                      columnIndex: indexedColumnID.index,
                    ),
                ],
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => table.addColumn(),
                  child: Container(
                    padding: EdgeInsets.only(right: 2),
                    child: Row(children: [Icon(Icons.add), Text('New column')]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

@bound_widget
Widget _tableHeaderCell(
  BuildContext context, {
  required Cursor<model.Table> table,
  required Cursor<model.Column<Object>> column,
  required int columnIndex,
}) {
  return Dropdown(
    style: ButtonStyle(alignment: Alignment.bottomLeft),
    childAnchor: Alignment.topCenter,
    dropdownAnchor: Alignment.topCenter,
    dropdown: ColumnConfigurationDropdown(
      column: column,
      table: table,
      columnIndex: columnIndex,
    ),
    child: Container(
      constraints: BoxConstraints.tightFor(
        width: column.width.get,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: const BorderSide(),
        ),
      ),
      padding: EdgeInsets.all(2),
      child: Text(column.title.get),
    ),
  );
}

@bound_widget
Widget _columnConfigurationDropdown(
  BuildContext context, {
  required Cursor<model.Column<Object>> column,
  required Cursor<model.Table> table,
  required int columnIndex,
}) {
  return TextButtonTheme(
    data: TextButtonThemeData(
      style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 10),
          minimumSize: Size(double.infinity, 0),
          textStyle: Theme.of(context).textTheme.bodyText1),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.all(10),
          child: BoundTextField(
            column.title,
            decoration: _tableCellBoundTextDecoration.copyWith(
              filled: true,
              fillColor: Colors.grey.shade200,
              contentPadding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Dropdown(
          childAnchor: Alignment.topRight,
          dropdownAnchor: Alignment.topLeft,
          dropdown: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final caze in model.ColumnCase.values)
                TextButton(
                  onPressed: () => column.setType(caze),
                  child: Text(caze.type.toString()),
                ),
            ],
          ),
          child: Text(column.caze.get.type.toString()),
        ),
        TextButton(
          onPressed: () {
            table.removeColumn(column.id.get);
          },
          child: Text('Delete column'),
        ),
      ],
    ),
  );
}

@bound_widget
Widget _tableRow(Cursor<model.Table> table, Cursor<model.RowID> rowID) {
  return IntrinsicHeight(
    child: Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide())),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final columnID in table.columnIDs.values)
            TableCell(table.columns[columnID.get], rowID, key: ValueKey(columnID.get)),
        ],
      ),
    ),
  );
}

@bound_widget
Widget _tableCell(Cursor<model.Column<Object>> column, Cursor<model.RowID> rowID) {
  return Container(
    constraints: BoxConstraints.tightFor(width: column.width.get),
    decoration: const BoxDecoration(border: Border(right: BorderSide())),
    padding: const EdgeInsets.all(2),
    child: Focus(
      skipTraversal: true,
      child: Builder(
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              if (Focus.of(context).hasFocus)
                const BoxShadow(
                  spreadRadius: 5,
                  blurRadius: 5,
                  color: Colors.grey,
                ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          child: Column(
            children: [
              column.cases(
                stringColumn: (column) => TableTextField(column.values[rowID.get]),
                booleanColumn: (column) => Expanded(
                  child: TableCheckbox(column.values[rowID.get]),
                ),
                intColumn: (column) => TableIntField(column.values[rowID.get]),
                dateColumn: (column) => TableDateField(column.values[rowID.get]),
                selectColumn: (column) => TableSelectField(column, rowID),
                linkColumn: (column) => TableLinkField(column, rowID),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

@bound_widget
Widget _tableLinkField(Cursor<model.LinkColumn> column, Cursor<model.RowID> rowID) {
  if (column.table.get == null || column.column.get == null) return Text('');
  return InheritCursor<model.State>(
    builder: (_, state) {
      final linkedTable = state.tables[column.table.get!];
      final linkedColumn = linkedTable.columns[column.column.get!];
      return Dropdown(
        childAnchor: Alignment.topLeft,
        dropdownAnchor: Alignment.topLeft,
        dropdown: Column(
          children: [
            for (final linkedRowID in linkedTable.rowIDs.get)
              TextButton(
                onPressed: () => column.values[rowID.get] = Optional(linkedRowID),
                child: Text(linkedColumn.values[linkedRowID].get.toString()),
              ),
          ],
        ),
        child: column.values[rowID.get].get.cases(
          some: (rowID) => Text(linkedColumn.values[rowID].get.toString()),
          none: () => Container(),
        ),
      );
    },
  );
}

@bound_widget
Widget _tableSelectField(Cursor<model.SelectColumn> column, Cursor<model.RowID> rowID) {
  return Dropdown(
    childAnchor: Alignment.topLeft,
    dropdownAnchor: Alignment.topLeft,
    dropdown: Column(
      children: [
        TextFormField(
          onFieldSubmitted: (result) {
            if (result.isNotEmpty) {
              column.possibleValues.add(result);
              column.values[rowID.get] = Optional(result);
            }
          },
        ),
        for (final possibleValue in column.possibleValues.get)
          TextButton(
            onPressed: () => column.values[rowID.get] = Optional(possibleValue),
            child: Text(possibleValue),
          ),
      ],
    ),
    child: Text(column.values[rowID.get].get.unwrap ?? ''),
  );
}

@bound_widget
Widget _tableCheckbox(Cursor<bool> checked) => Checkbox(
      value: checked.get,
      onChanged: (newChecked) => checked.set(newChecked!),
      visualDensity: const VisualDensity(
        horizontal: VisualDensity.minimumDensity,
        vertical: VisualDensity.minimumDensity,
      ),
      splashRadius: 0,
    );

@bound_widget
Widget _tableIntField(Cursor<int> value) {
  final asString = value.then<String>(
    Lens.mk(
      (value) => GetResult(value.toString(), []),
      (value, update) => MutResult.allChanged(int.tryParse(update(value.toString())) ?? value),
    ),
  );
  return BoundTextField(
    asString,
    keyboardType: TextInputType.number,
    decoration: _tableCellBoundTextDecoration,
  );
}

@bound_widget
Widget _tableTextField(Cursor<String> text) {
  return BoundTextField(
    text,
    maxLines: null,
    decoration: _tableCellBoundTextDecoration,
  );
}

const _tableCellBoundTextDecoration = InputDecoration(border: InputBorder.none, isDense: true);

@bound_widget
Widget _tableDateField(Cursor<DateTime> date) {
  return Form(
    child: Builder(
      builder: (context) => Focus(
        skipTraversal: true,
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            Form.of(context)!.save();
          }
        },
        onKey: (focusNode, keyEvent) {
          if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
            focusNode.unfocus();
          } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
            focusNode.unfocus();
          }
        },
        child: InputDatePickerFormField(
          initialDate: date.get,
          firstDate: DateTime.utc(0),
          lastDate: DateTime.utc(10000),
          fieldLabelText: null,
          onDateSaved: (newDate) => date.set(newDate),
        ),
      ),
    ),
  );
}
