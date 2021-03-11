import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:reorderables/reorderables.dart';
import '../model/table.dart' as model;
import 'primitives.dart';
import 'pinned_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'table.g.dart';

class TableWidget extends HookWidget {
  final Cursor<model.Table> table;
  TableWidget(this.table, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final horizontalScrollController = useScrollController();
    final scrollController = useScrollController();
    final table = useBoundCursor(this.table);

    double width = 0;
    for (int column = 0; column < table.columns.length.get; column++) {
      width += table.columns[column].width.get;
      if (column != 0) {
        width += 1;
      }
    }
    width += 100;

    return Scrollbar(
      isAlwaysShown: true,
      controller: horizontalScrollController,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalScrollController,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: PrimaryScrollController(
            controller: scrollController,
            child: Scrollbar(
              isAlwaysShown: true,
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CustomScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  slivers: [
                    SliverPinnedHeader(
                      builder: (_, overlapsContent) => AnimatedContainer(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          boxShadow: [
                            if (overlapsContent)
                              BoxShadow(
                                blurRadius: 3,
                                spreadRadius: -4,
                                offset: Offset(0, 4.0),
                                color: Colors.grey,
                              )
                          ],
                        ),
                        duration: Duration(milliseconds: 100),
                        child: TableHeader(table),
                      ),
                    ),
                    ReorderableSliverList(
                      onReorder: (a, b) {
                        table.columns.forEach((column) {
                          final bVal = column.values[b].get;
                          column.values[b].set(column.values[a].get);
                          column.values[a].set(bVal);
                        });
                      },
                      delegate: ReorderableSliverChildBuilderDelegate(
                        (_, i) => TableRow(table, i),
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
}

@bound_widget
Widget _tableHeader(BuildContext context, Cursor<model.Table> table) {
  final scrollController = useScrollController();

  return Container(
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      border: Border(bottom: BorderSide()),
    ),
    child: IntrinsicHeight(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            child:
                // TextButton(
                //   onPressed: () {},
                //   child: Text(table.title.get, style: Theme.of(context).textTheme.headline3),
                // ),
                BoundTextField(
              table.title,
              style: Theme.of(context).textTheme.headline3,
              decoration: _tableCellBoundTextDecoration,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                // scrollController: scrollController,
                // onReorder: (a, b) {
                //   final aVal = table.columns[a].get;
                //   table.columns[a].set(table.columns[b].get);
                //   table.columns[b].set(aVal);
                // },
                children: [
                  for (final indexedColumn in table.columns.indexedValues)
                    TableHeaderCell(
                      key: ValueKey(indexedColumn.index),
                      table: table,
                      column: indexedColumn.value,
                      columnIndex: indexedColumn.index,
                    ),
                ],
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => table.columns.add(
                    model.StringColumn.empty(length: table.length.get),
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
    isOpenOnHover: false,
    childAnchor: Alignment.bottomLeft,
    dropdownAnchor: Alignment.topLeft,
    dropdown: IntrinsicWidth(
      child: ColumnConfigurationDropdown(
        column: column,
        table: table,
        columnIndex: columnIndex,
      ),
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
      padding: const EdgeInsets.all(2),
      alignment: Alignment.bottomLeft,
      child: Text(column.title.get),
    ),
  );
}

@bound_widget
Widget _columnConfigurationDropdown({
  required Cursor<model.Column<Object>> column,
  required Cursor<model.Table> table,
  required int columnIndex,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BoundTextField(column.title),
      Dropdown(
        childAnchor: Alignment.topRight,
        dropdownAnchor: Alignment.topLeft,
        dropdown: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final caze in model.ColumnCase.values)
              GestureDetector(
                onTap: () => table.setColumnType(columnIndex, caze),
                child: Text(caze.type.toString()),
              ),
          ],
        ),
        child: Text(column.caze.get.type.toString()),
      ),
      IconButton(
        icon: Icon(Icons.remove),
        onPressed: () {
          table.removeColumn(columnIndex);
        },
      ),
    ],
  );
}

@bound_widget
Widget _tableRow(Cursor<model.Table> table, int rowIndex) {
  return IntrinsicHeight(
    child: Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide())),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final column in table.columns.values) TableCell(column, rowIndex),
        ],
      ),
    ),
  );
}

@bound_widget
Widget _tableCell(Cursor<model.Column<Object>> column, int rowIndex) {
  return Container(
    constraints: BoxConstraints(
      minWidth: column.width.get,
      maxWidth: column.width.get,
    ),
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
                stringColumn: (column) => TableTextField(column.values[rowIndex]),
                booleanColumn: (column) => TableCheckbox(column.values[rowIndex]),
                intColumn: (column) => TableIntField(column.values[rowIndex]),
                dateColumn: (column) => TableDateField(column.values[rowIndex]),
              ),
            ],
          ),
        ),
      ),
    ),
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
  final keyboardFocusNode = useFocusNode(skipTraversal: true);

  return Form(
    child: Builder(
      builder: (context) => Focus(
        skipTraversal: true,
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            Form.of(context)!.save();
          }
        },
        child: RawKeyboardListener(
          focusNode: keyboardFocusNode,
          onKey: (keyEvent) {
            if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
              keyboardFocusNode.unfocus();
            } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
              keyboardFocusNode.unfocus();
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
    ),
  );
}

class PersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  PersistentHeaderDelegate(this.child, {this.height = 30});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return AnimatedContainer(
      width: double.infinity,
      decoration: BoxDecoration(
        boxShadow: [
          if (shrinkOffset > 0)
            BoxShadow(
              blurRadius: 3,
              spreadRadius: 0,
              offset: Offset(0, 0),
              color: Colors.grey,
            )
        ],
      ),
      duration: Duration(milliseconds: 100),
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
