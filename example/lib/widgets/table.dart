import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:reorderables/reorderables.dart';
import '../model/table.dart' as model;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TableWidget extends HookWidget {
  final Cursor<model.Table> table;
  TableWidget(this.table);

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
          child: Scrollbar(
            isAlwaysShown: true,
            controller: scrollController,
            child: CustomScrollView(
              controller: scrollController,
              scrollDirection: Axis.vertical,
              // shrinkWrap: true, // want to do this, but it breaks the persistent header for some reason :/
              slivers: [
                SliverPersistentHeader(
                  delegate:
                      PersistentHeaderDelegate(buildHeader(), height: 30.0),
                  pinned: true,
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
                    (_, i) => buildRow(i),
                    childCount: table.length.get,
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    Container(
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
    );
  }

  Widget buildHeader() {
    final scrollController = useScrollController();

    return table.bind(
      (context, table) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(bottom: BorderSide()),
        ),
        child: ReorderableRow(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          scrollController: scrollController,
          onReorder: (a, b) {
            final aVal = table.columns[a].get;
            table.columns[a].set(table.columns[b].get);
            table.columns[b].set(aVal);
          },
          children: [
            for (final columnIndex
                in Iterable<int>.generate(table.columns.length.get))
              table.columns[columnIndex].bind(
                (context, column) => Container(
                  constraints: BoxConstraints.tightFor(
                    width: column.width.get,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      left: columnIndex == 0 ? BorderSide.none : BorderSide(),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: TableTextField(column.title),
                ),
                key: UniqueKey(),
              ),
            IconButton(
              key: UniqueKey(),
              icon: Icon(Icons.add),
              onPressed: () => table.columns.add(
                model.StringColumn.empty(length: table.length.get),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRow(int rowIndex) {
    return table.bind(
      (_, table) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            table.columns.length.get,
            (columnIndex) {
              final column = table.columns[columnIndex];
              return column.width.build(
                (context, width) => Container(
                  constraints: BoxConstraints(
                    minWidth: width,
                    maxWidth: width,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: rowIndex == 0 ? BorderSide.none : const BorderSide(),
                      left: columnIndex == 0
                          ? BorderSide.none
                          : const BorderSide(),
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Column(
                    children: [
                      TableTextField(
                        column.cases(
                          string: (column) => column.values[rowIndex],
                        ),
                      )
                    ],
                  ),
                ),
                key: UniqueKey(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class TableTextField extends HookWidget {
  final Cursor<String> text;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;

  TableTextField(this.text, {this.focusNode, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    final boundText = useBoundCursor(text);
    final textController = useTextEditingController(text: boundText.get);
    final focusNode = this.focusNode ??
        useFocusNode(onKey: (focusNode, keyEvent) {
          if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
            focusNode.unfocus();
            return true;
          }
          return false;
        });
    useListenable(focusNode);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          if (focusNode.hasFocus)
            const BoxShadow(
              spreadRadius: 5,
              blurRadius: 5,
              color: Colors.grey,
            ),
        ],
      ),
      child: Form(
        child: Builder(
          builder: (context) => Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                Form.of(context)!.save();
              }
            },
            child: RawKeyboardListener(
              focusNode: focusNode,
              onKey: (keyEvent) {
                if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
                  Form.of(context)!.save();
                } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
                  if (!keyEvent.isShiftPressed) {
                    Form.of(context)!.save();
                  }
                }
              },
              child: TextFormField(
                maxLines: null,
                controller: textController,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(4),
                  isDense: true,
                ),
                style: Theme.of(context).textTheme.bodyText2,
                textAlignVertical: TextAlignVertical.top,
                onSaved: (newText) {
                  boundText.set(newText!);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      height: double.infinity,
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
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}
