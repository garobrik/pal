import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import '../model/table.dart' as model;
import 'primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'table_row.g.dart';

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
