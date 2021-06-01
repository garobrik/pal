import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'cset.g.dart';

@immutable
@ReifiedLens(type: ReifiedKind.List)
class CSet<Value> extends Iterable<Value> with _CSetMixin<Value> {
  @skip
  final SplayTreeSet<Value> _values;
  CSet([Iterable<Value>? values]) : _values = SplayTreeSet.of(values ?? {});

  @override
  @reify
  int get length => _values.length;

  CSet<Value> remove(Value value) {
    final newSet = CSet(_values);
    newSet._values.remove(value);
    return newSet;
  }

  Diff _remove_mutated(Value value) =>
      !_values.contains(value) ? const Diff() : const Diff.allChanged();

  CSet<Value> add(Value value) {
    final newSet = CSet(_values);
    newSet._values.add(value);
    return newSet;
  }

  Diff _add_mutated(Value value) =>
      _values.contains(value) ? const Diff() : const Diff.allChanged();

  @override
  Iterator<Value> get iterator => _values.iterator;

  @override
  bool operator ==(Object other) {
    if (other is! Set<Value>) return false;
    return iterableEqual(other);
  }

  @override
  int get hashCode => hash(this);
}
