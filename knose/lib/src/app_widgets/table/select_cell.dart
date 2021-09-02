import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;

part 'select_cell.g.dart';

@reader_widget
Widget _selectField(
  BuildContext context,
  Reader reader, {
  required Cursor<model.SelectColumn> column,
  required Cursor<Optional<model.TagID>> row,
  bool enabled = true,
}) {
  return SelectCell(
    cellTags: (reader) => row.read(reader).cases(
          some: (id) => [column.tags[id].whenPresent.read(reader)],
          none: () => [],
        ),
    columnTags: (reader) => column.tags.keys
        .read(reader)
        .map((id) => column.tags[id].whenPresent.read(reader))
        .toList(),
    onDelete: (tag) => row.set(Optional.none()),
    onCreate: (tag) {
      final id = column.addTag(tag);
      row.set(Optional(id));
    },
    onSelect: (tag) => row.set(Optional(tag.id)),
    enabled: enabled,
  );
}

@reader_widget
Widget _multiselectField(
  BuildContext context,
  Reader reader, {
  required Cursor<model.MultiselectColumn> column,
  required Cursor<CSet<model.TagID>> row,
  bool enabled = true,
}) {
  return SelectCell(
    cellTags: (reader) =>
        row.read(reader).map((id) => column.tags[id].whenPresent.read(reader)).toList(),
    columnTags: (reader) => column.tags.keys
        .read(reader)
        .map((id) => column.tags[id].whenPresent.read(reader))
        .toList(),
    onDelete: (tag) => row.remove(tag.id),
    onCreate: (tag) {
      final id = column.addTag(tag);
      row.add(id);
    },
    onSelect: (tag) => row.add(tag.id),
    enabled: enabled,
  );
}

@reader_widget
Widget _selectCell(
  Reader reader,
  BuildContext context, {
  required List<model.Tag> Function(Reader) cellTags,
  required List<model.Tag> Function(Reader) columnTags,
  required void Function(model.Tag) onDelete,
  required void Function(model.Tag) onCreate,
  required void Function(model.Tag) onSelect,
  bool enabled = true,
}) {
  final isOpen = useCursor(false);
  final dropdownFocus = useFocusNode();

  final tagChipBuilder = (model.Tag tag, {bool deleteable = false}) => Chip(
        onDeleted: !deleteable ? null : () => onDelete(tag),
        label: Text(tag.name, softWrap: true, overflow: TextOverflow.ellipsis),
        backgroundColor: tag.color,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity(horizontal: 0, vertical: -4),
        deleteIcon: Icon(Icons.close, size: 16),
      );

  return DeferredDropdown(
    isOpen: isOpen,
    offset: Offset(-1, -1),
    modifyConstraints: (constraints) => BoxConstraints(
      minWidth: constraints.maxWidth + 2,
      maxWidth: max(200, constraints.maxWidth + 2),
      minHeight: constraints.maxHeight + 2,
    ),
    childAnchor: Alignment.topLeft,
    dropdownFocus: dropdownFocus,
    dropdown: ReaderWidget(
      builder: (_, reader) {
        final tag = useCursor(model.Tag(
          name: '',
          color: _tagColors.elementAt(
            Random().nextInt(_tagColors.length),
          ),
        ));

        return Container(
          color: Theme.of(context).colorScheme.background,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                children: [
                  for (final tag in cellTags(reader)) tagChipBuilder(tag, deleteable: true),
                  Container(
                    constraints: BoxConstraints(maxWidth: 100),
                    child: BoundTextFormField(
                      tag.name,
                      focusNode: dropdownFocus,
                      style: Theme.of(context).textTheme.bodyText2,
                      decoration: InputDecoration(
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
              Material(
                child: ReaderWidget(
                  builder: (_, reader) => Column(
                    children: [
                      if (tag.name.read(reader).isNotEmpty)
                        TextButton(
                          onPressed: () {
                            onCreate(tag.read(null));
                            isOpen.set(false);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text('Create '),
                              Expanded(
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: tagChipBuilder(tag.read(reader)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: columnTags(reader).length,
                        itemBuilder: (_, index) => ReaderWidget(
                          builder: (_, reader) {
                            final tag = columnTags(reader)[index];
                            return TextButton(
                              onPressed: () => onSelect(tag),
                              child: Container(
                                alignment: Alignment.centerLeft,
                                child: tagChipBuilder(tag),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
    child: TextButton(
      style: ButtonStyle(
        padding: MaterialStateProperty.all(EdgeInsets.symmetric(vertical: 15, horizontal: 5)),
        alignment: Alignment.topLeft,
      ),
      onPressed: () => isOpen.set(true),
      child: Wrap(
        runSpacing: 5,
        spacing: 5,
        alignment: WrapAlignment.start,
        children: cellTags(reader).map(tagChipBuilder).toList(),
      ),
    ),
  );
}

final _tagColors = const [
  Colors.amber,
  Colors.blue,
  Colors.cyan,
  Colors.brown,
  Colors.orange,
  Colors.green,
  Colors.indigo,
  Colors.pink,
  Colors.red
].map((c) => c.shade50);
