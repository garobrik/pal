import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class HierarchicalOrderTraversalPolicy extends FocusTraversalPolicy
    with DirectionalFocusTraversalPolicyMixin {
  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    final sorted = _TrieList<FocusNode>(null);
    for (final descendant in descendants) {
      _place(sorted, descendant);
    }
    _sortSiblings(sorted);
    return sorted;
  }

  static void _place(_TrieList<FocusNode> sorted, FocusNode node) {
    if (sorted.isEmpty) {
      sorted.element = node;
    } else if (sorted.element == null || node.ancestors.contains(sorted.element)) {
      final children = <_TrieList<FocusNode>>[];
      for (final subTrie in sorted.children) {
        if (subTrie.element!.ancestors.contains(node)) {
          children.add(subTrie);
        } else if (node.ancestors.contains(subTrie.element!)) {
          _place(subTrie, node);
        }
      }
      sorted.children.removeWhere(children.contains);
      sorted.children.add(_TrieList(node, children));
    } else if (sorted.element!.ancestors.contains(node)) {
      sorted.children = [_TrieList(sorted.element, sorted.children)];
      sorted.element = node;
    } else {
      sorted.children = [_TrieList(sorted.element, sorted.children), _TrieList(node)];
      sorted.element = null;
    }
  }

  static void _sortSiblings(_TrieList<FocusNode> sorted) {
    if (sorted.isEmpty) return;
    _doSortSiblings(
      (sorted.first.context!.getElementForInheritedWidgetOfExactType<Directionality>()!.widget
              as Directionality)
          .textDirection,
      sorted,
    );
  }

  static void _doSortSiblings(TextDirection directionality, _TrieList<FocusNode> sorted) {
    mergeSort<_TrieList<FocusNode>>(sorted.children, compare: (t1, t2) {
      return _comparePositions(directionality, t1.element!, t2.element!);
    });
    for (final child in sorted.children) {
      _doSortSiblings(directionality, child);
    }
  }

  static int _comparePositions(TextDirection directionality, FocusNode a, FocusNode b) {
    if (a.offset.dy + (3 * a.size.height / 4) < b.offset.dy) return -1;
    if (b.offset.dy + (3 * b.size.height / 4) < a.offset.dy) return 1;
    final ltr = directionality == TextDirection.ltr;
    final aStart = ltr ? a.offset.dx : a.offset.dx + a.size.width;
    final bStart = ltr ? b.offset.dx : b.offset.dx + b.size.width;
    return aStart < bStart ? -1 : 1;
  }
}

extension HierarchicalDescendants on FocusNode {
  Iterable<FocusNode> get hierarchicalTraversableDescendants {
    if (!descendantsAreFocusable) return const [];
    final descendants = _traversableDescendants;
    descendants.element = null;
    HierarchicalOrderTraversalPolicy._sortSiblings(descendants);
    descendants.removeWhere((node) => !node.canRequestFocus || node.skipTraversal);
    return descendants;
  }

  _TrieList<FocusNode> get _traversableDescendants {
    return _TrieList(this, [
      for (final child in children)
        if (child.descendantsAreFocusable) child._traversableDescendants
    ]);
  }
}

class _TrieList<T extends Object> extends Iterable<T> {
  T? element;
  List<_TrieList<T>> children;

  _TrieList(this.element, [List<_TrieList<T>>? children]) : children = children ?? [];

  @override
  Iterator<T> get iterator => elements.iterator;

  Iterable<T> get elements sync* {
    if (element != null) yield element!;
    for (final child in children) {
      yield* child;
    }
  }

  void removeWhere(bool Function(T) predicate) {
    if (element != null && predicate(element!)) element = null;
    for (final child in children) {
      child.removeWhere(predicate);
    }
  }
}
