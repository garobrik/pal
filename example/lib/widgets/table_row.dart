import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import '../model/table.dart' as model;
import 'page.dart';
import 'primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'table_row.g.dart';

@reader_widget
Widget _tableRow(
    BuildContext context, Reader reader, Cursor<model.Table> table, Cursor<model.RowID> rowID) {
  return IntrinsicHeight(
    child: Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide())),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              RawDialogRoute(
                pageBuilder: (_, __, ___) => Scaffold(body: PageWidget(table, rowID)),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.open_in_full, size: 20.0),
                Text(' Open'),
              ],
            ),
          ),
          for (final columnID in table.columnIDs.values(reader))
            TableCell(
              table.columns[columnID.read(reader)].nonnull,
              rowID,
              key: ValueKey(columnID.read(reader)),
            ),
        ],
      ),
    ),
  );
}

@reader_widget
Widget _tableCell(Reader reader, Cursor<model.Column> column, Cursor<model.RowID> rowID) {
  return Container(
    constraints: BoxConstraints.tightFor(width: column.width.read(reader)),
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
              column.rows.cases(
                reader,
                stringColumn: (column) => TableTextField(column.values[rowID.read(reader)]),
                booleanColumn: (column) => Expanded(
                  child: TableCheckbox(column.values[rowID.read(reader)].orElse(false)),
                ),
                intColumn: (column) => TableIntField(column.values[rowID.read(reader)]),
                dateColumn: (column) => TableDateField(column.values[rowID.read(reader)]),
                selectColumn: (column) => TableSelectField(column, rowID),
                multiselectColumn: (column) => TableMultiselectField(column, rowID),
                linkColumn: (column) => TableLinkField(column, rowID),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

@reader_widget
Widget _tableLinkField(Reader reader, Cursor<model.LinkColumn> column, Cursor<model.RowID> rowID) {
  if (column.table.read(reader) == null || column.column.read(reader) == null) return Text('');
  return InheritCursor<model.State>(
    builder: (_, reader, state) {
      final linkedTable = state.tables[column.table.read(reader)!].nonnull;
      // final linkedColumn = linkedTable.columns[column.column.get!];
      return Dropdown(
        childAnchor: Alignment.topLeft,
        dropdownAnchor: Alignment.topLeft,
        dropdown: Column(
          children: [
            for (final linkedRowID in linkedTable.rowIDs.read(reader))
              TextButton(
                onPressed: () => column.values[rowID.read(reader)] = linkedRowID,
                child: Text('$linkedRowID'),
              ),
          ],
        ),
        child: column.values.keys.read(reader).contains(rowID)
            ? Text(column.values[rowID.read(reader)].read(reader).toString())
            : Container(),
      );
    },
  );
}

@reader_widget
Widget _tableSelectField(
  Reader reader,
  Cursor<model.SelectColumn> column,
  Cursor<model.RowID> rowID,
) {
  return Dropdown(
    childAnchor: Alignment.topLeft,
    dropdownAnchor: Alignment.topLeft,
    dropdown: Column(
      children: [
        TextFormField(
          onFieldSubmitted: (result) {
            if (result.isNotEmpty) {
              column.possibleValues.add(result);
              column.values[rowID.read(reader)] = result;
            }
          },
        ),
        for (final possibleValue in column.possibleValues.read(reader))
          TextButton(
            onPressed: () => column.values[rowID.read(reader)] = possibleValue,
            child: Text(possibleValue),
          ),
      ],
    ),
    child: Text(column.values[rowID.read(reader)].read(reader) ?? ''),
  );
}

@reader_widget
Widget _tableMultiselectField(
  Reader reader,
  Cursor<model.MultiselectColumn> column,
  Cursor<model.RowID> rowID,
) {
  final row = column.values[rowID.read(null)];

  return Dropdown(
    childAnchor: Alignment.topLeft,
    dropdownAnchor: Alignment.topLeft,
    dropdown: Column(
      children: [
        TextFormField(
          onFieldSubmitted: (result) {
            if (result.isNotEmpty) {
              column.possibleValues.add(result);
              row.set(row.read(null)?.add(result) ?? CSet({result}));
            }
          },
        ),
        for (final possibleValue in column.possibleValues.read(reader))
          Row(
            children: [
              Checkbox(
                onChanged: (selected) {
                  if (selected!) {
                    row.set(row.read(null)?.add(possibleValue) ?? CSet({possibleValue}));
                  } else {
                    row.set(row.read(null)?.remove(possibleValue));
                  }
                },
                value: column.values[rowID.read(reader)].read(reader)?.contains(possibleValue) ??
                    false,
              ),
              Text(possibleValue),
            ],
          ),
      ],
    ),
    child: Wrap(
      children: [
        for (final value in row.read(reader) ?? CSet<String>())
          Padding(
            padding: const EdgeInsets.all(3.0),
            child: Material(
              color: Colors.amber.shade200,
              child: Text(value),
            ),
          ),
      ],
    ),
  );
}

@reader_widget
Widget _tableCheckbox(Reader reader, Cursor<bool> checked) => Checkbox(
      value: checked.read(reader),
      onChanged: (newChecked) => checked.set(newChecked!),
      visualDensity: const VisualDensity(
        horizontal: VisualDensity.minimumDensity,
        vertical: VisualDensity.minimumDensity,
      ),
      splashRadius: 0,
    );

@reader_widget
Widget _tableIntField(Cursor<int?> value) {
  final asString = value.then<String>(
    Lens(
      Path.empty(),
      (value) => value?.toString() ?? '',
      (value, update) => int.tryParse(update(value.toString())) ?? value,
    ),
  );
  return BoundTextField(
    asString,
    keyboardType: TextInputType.number,
    decoration: _tableCellBoundTextDecoration,
  );
}

@reader_widget
Widget _tableTextField(Cursor<String?> text) {
  return BoundTextField(
    text.orElse(''),
    maxLines: null,
    decoration: _tableCellBoundTextDecoration,
  );
}

const _tableCellBoundTextDecoration = InputDecoration(border: InputBorder.none, isDense: true);

@reader_widget
Widget _tableDateField(Reader reader, Cursor<DateTime?> date) {
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
          initialDate: date.read(reader),
          firstDate: DateTime.utc(0),
          lastDate: DateTime.utc(10000),
          fieldLabelText: null,
          onDateSaved: (newDate) => date.set(newDate),
        ),
      ),
    ),
  );
}
