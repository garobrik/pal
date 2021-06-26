import 'package:example/widgets/primitives.dart';

import '../model/table.dart' as model;
import 'table_header.dart';
import 'table_row.dart' as table_row;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'page.g.dart';

@reader_widget
Widget _pageWidget(Cursor<model.Table> table, Cursor<model.RowID> rowID) {
  return Column(
    children: [
      PageHeader(table, rowID),
      PageBody(table, rowID),
    ],
  );
}

@reader_widget
Widget _pageHeader(Reader reader, Cursor<model.Table> table, Cursor<model.RowID> rowID) {
  return Row(
    children: [
      Column(
        children: [
          for (final columnID in table.columnIDs.values(reader))
            TableHeaderCell(
              table: table,
              column: table.columns[columnID.read(reader)].nonnull,
            ),
        ],
      ),
      Column(
        children: [
          for (final columnID in table.columnIDs.values(reader))
            table_row.TableCell(
              table.columns[columnID.read(reader)].nonnull,
              rowID,
            ),
        ],
      ),
    ],
  );
}

@reader_widget
Widget _pageBody(Reader reader, Cursor<model.Table> table, Cursor<model.RowID> rowID) {
  final page = table.pages[rowID.read(reader)].orElse(model.Page(''));

  return BoundTextField(page.contents, maxLines: null);
}
