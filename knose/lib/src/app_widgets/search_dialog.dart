import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/infra_widgets.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/shortcuts.dart';

part 'search_dialog.g.dart';

@reader_widget
Widget _searchDialog(Reader reader, Cursor<model.State> state) {
  final searchText = useCursor('');

  return Dialog(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search),
            Expanded(
              child: BoundTextFormField(
                searchText,
              ),
            ),
          ],
        ),
        Divider(height: 0),
        for (final tableID in state.tableIDs.read(reader))
          if (state.tables[tableID].nonnull.title.read(reader).startsWith(searchText.read(reader)))
            TextButton(
              onPressed: () {},
              child: Row(
                children: [
                  Icon(Icons.menu),
                  Text(state.tables[tableID].nonnull.title.read(reader))
                ],
              ),
            ),
      ],
    ),
  );
}
