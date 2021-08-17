import 'dart:math' as math;

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
}) {
  final isOpen = useCursor(false);
  final dropdownFocus = useFocusNode();
  final tagID = row.read(reader).unwrap;

  final tagChipBuilder = (model.TagID tagID, {bool deleteable = false}) => ReaderWidget(
        builder: (_, reader) {
          final tag = column.tags[tagID].whenPresent;
          final chip = Chip(
            onDeleted: !deleteable ? null : () => row.set(Optional.none()),
            label: Text(tag.name.read(reader)),
            backgroundColor: tag.color.read(reader),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity(horizontal: 0, vertical: -4),
            deleteIcon: Icon(Icons.close, size: 16),
          );
          return chip;
        },
      );

  return ReplacerWidget(
    dropdownFocus: dropdownFocus,
    isOpen: isOpen,
    offset: Offset(-1, -1),
    dropdownBuilder: (_, replacedSize) => ReaderWidget(
      builder: (_, reader) {
        final text = useCursor('');
        final colors = const [
          Colors.amber,
          Colors.blue,
          Colors.cyan,
          Colors.brown,
          Colors.orange,
          Colors.green,
          Colors.indigo,
          Colors.pink,
          Colors.red
        ].map((c) => c.shade200);
        final color = useMemoized(() => colors.elementAt(math.Random().nextInt(colors.length)));

        return Container(
          constraints: BoxConstraints(
            maxWidth: math.max(replacedSize.width, 200),
            minWidth: replacedSize.width,
            minHeight: replacedSize.height,
          ),
          color: Theme.of(context).colorScheme.background,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                children: [
                  if (tagID != null) tagChipBuilder(tagID, deleteable: true),
                  Container(
                    constraints: BoxConstraints(maxWidth: 100),
                    child: BoundTextFormField(
                      text,
                      focusNode: dropdownFocus,
                      style: Theme.of(context).textTheme.bodyText2,
                      decoration: InputDecoration(focusedBorder: InputBorder.none),
                    ),
                  ),
                ],
              ),
              Material(
                child: ReaderWidget(
                  builder: (_, reader) => Column(
                    children: [
                      if (text.read(reader).isNotEmpty)
                        TextButton(
                          onPressed: () {
                            final tag = model.Tag(name: text.read(null), color: color);
                            final newTagID = column.addTag(tag);
                            row.set(Optional(newTagID));
                            isOpen.set(false);
                          },
                          child: Row(
                            children: [
                              Text('Create '),
                              Chip(
                                label: Text(text.read(reader)),
                                backgroundColor: color,
                                padding: EdgeInsets.zero,
                                labelPadding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: column.tags.length.read(reader),
                        itemBuilder: (_, index) => ReaderWidget(
                          builder: (_, reader) {
                            final tagID = column.tags.keys.read(reader).elementAt(index);
                            return TextButton(
                              onPressed: () => row.set(Optional(tagID)),
                              child: Row(children: [tagChipBuilder(tagID)]),
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
      onPressed: () => isOpen.set(true),
      child: Wrap(children: [if (tagID != null) tagChipBuilder(tagID)]),
    ),
  );
}
