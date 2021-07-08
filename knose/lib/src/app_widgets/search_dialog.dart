import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;

part 'search_dialog.g.dart';

@reader_widget
Widget _searchDialog(Reader reader, Cursor<model.State> state) {
  final searchText = useCursor('');

  return Shortcuts(
    shortcuts: {LogicalKeySet(LogicalKeyboardKey.escape): DismissIntent()},
    child: Dialog(
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
                  autofocus: true,
                  decoration: InputDecoration(filled: false, focusedBorder: InputBorder.none,),
                ),
              ),
            ],
          ),
          Divider(height: 0),
          for (final tableID in state.tableIDs.read(reader))
            if (state.tables[tableID].nonnull.title
                .read(reader)
                .toLowerCase()
                .startsWith(searchText.read(reader).toLowerCase()))
              TextButton(
                key: ValueKey(tableID),
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
    ),
  );
}
