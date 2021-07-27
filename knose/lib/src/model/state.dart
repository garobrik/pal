import 'package:meta/meta.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart';

part 'state.g.dart';

@immutable
@reify
class State with _StateMixin {
  @override
  final Dict<NodeID, Object> nodes;

  @override
  final Vec<TableID> tableIDs;

  @override
  final Vec<PageID> pageIDs;

  const State({
    this.nodes = const Dict(),
    this.tableIDs = const Vec(),
    this.pageIDs = const Vec(),
  });
}

extension StateReads on Cursor<State> {
  Cursor<Table> getTable(TableID id) {
    return nodes[NodeID.from(id.id)].nonnull.cast<Table>();
  }

  Cursor<Page> getPage(PageID id) {
    return nodes[NodeID.from(id.id)].nonnull.cast<Page>();
  }
}

extension StateMutations on Cursor<State> {
  TableID addTable([Table? table]) {
    table ??= Table();
    nodes[NodeID.from(table.id.id)] = table;
    tableIDs.add(table.id);
    return table.id;
  }

  PageID addPage([Page? page]) {
    page ??= Page();
    nodes[NodeID.from(page.id.id)] = page;
    pageIDs.add(page.id);
    return page.id;
  }
}
