import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/pal.dart' as pal;

part 'link_cell.g.dart';

@reader
Widget _linkField(
  BuildContext context, {
  required Ctx ctx,
  required Cursor<model.Column> column,
  required Cursor<Optional<model.RowID>> rowCursor,
  bool enabled = true,
}) {
  final isOpen = useCursor(false);
  const model.TableID? tableID = null; //column.table.read(ctx) as model.TableID?;
  String? title(Ctx ctx) {
    final row = rowCursor.read(ctx).unwrap;
    if (row == null || tableID == null) return null;
    final table = ctx.db.get(tableID).whenPresent;
    final column = table.columns[table.titleColumn.read(ctx)].whenPresent;
    final palImpl = pal.findImpl(
      ctx,
      model.columnImplDef.asType({model.columnImplImplementerID: column.impl.type.read(ctx)}),
    )!;
    final getData = palImpl.interfaceAccess(ctx, model.columnImplGetDataID);
    final data = getData.callFn(ctx, Dict({'row': row, 'impl': column.impl})) as Cursor<Object>;
    return data.cast<Optional<Object>>().optionalCast<String>().read(ctx).unwrap;
  }

  final focusForRow = useMemoized(() {
    final map = <model.RowID, FocusNode>{};
    return (model.RowID rowID) => map.putIfAbsent(rowID, () => FocusNode());
  });
  FocusNode? currentFocus;
  if (tableID != null) {
    final table = ctx.db.get(tableID).whenPresent;
    final length = table.rowIDs.length.read(ctx);
    if (length > 0) {
      currentFocus = focusForRow(table.rowIDs[0].read(ctx));
    }
  }

  return DeferredDropdown(
    offset: const Offset(-1, -1),
    isOpen: isOpen,
    dropdownFocus: currentFocus,
    childAnchor: Alignment.topLeft,
    dropdown: ReaderWidget(
      ctx: ctx,
      builder: (_, ctx) {
        final table = ctx.db.get(tableID!).whenPresent;
        final width = table.columns.keys
            .read(ctx)
            .map(
              (colID) => table.columns[colID].whenPresent.width.read(ctx),
            )
            .reduce((a, b) => a + b);

        return Container(
          constraints: BoxConstraints(maxWidth: width),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: table.rowIDs.length.read(ctx),
            itemBuilder: (_, index) => ReaderWidget(
              ctx: ctx,
              builder: (_, ctx) {
                final rowID = table.rowIDs[index].read(ctx);
                return TextButton(
                  focusNode: focusForRow(rowID),
                  style: ButtonStyle(
                    alignment: Alignment.centerLeft,
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () => rowCursor.set(Optional(rowID)),
                  child: TableRow(
                    ctx: ctx,
                    table: table,
                    rowID: rowID,
                    enabled: false,
                    trailingNewColumnSpace: false,
                    key: ValueKey(rowID),
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
    child: TextButton(
      style: const ButtonStyle(alignment: Alignment.centerLeft),
      onPressed: (tableID == null || !enabled) ? null : () => isOpen.set(true),
      child: Text(
        title(ctx) ?? '',
        style: const TextStyle(decoration: TextDecoration.underline),
      ),
    ),
  );
}
