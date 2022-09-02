import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'cset.g.dart';

@immutable
@ReifiedLens(type: ReifiedKind.list)
class CSet<Value> extends Iterable<Value> with _CSetMixin<Value> {
  @override
  @skip
  final Set<Value> _values;
  const CSet([this._values = const {}]);

  @override
  @reify
  int get length => _values.length;

  CSet<Value> remove(Value value) => CSet(Set.of(_values)).._values.remove(value);

  Diff _remove_mutated(Value value) =>
      !_values.contains(value) ? const Diff() : const Diff.allChanged();

  CSet<Value> add(Value value) => CSet(Set.of(_values)).._values.add(value);

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
  int get hashCode => Object.hashAllUnordered(this);
}
