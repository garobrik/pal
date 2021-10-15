import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'map.g.dart';

@immutable
@ReifiedLens(type: ReifiedKind.Map)
class Dict<Key extends Object, Value> extends Iterable<MapEntry<Key, Value>>
    with _DictMixin<Key, Value> {
  @override
  @skip
  final Map<Key, Value> _values;

  const Dict([this._values = const {}]);

  @override
  @reify
  int get length => _values.length;

  @reify
  Iterable<Key> get keys => _values.keys;

  @reify
  Optional<Value> operator [](Key key) => Optional.fromNullable(_values[key]);
  Dict<Key, Value> mut_array_op(Key key, Optional<Value> update) => update.cases(
        some: (update) => Dict(Map.of(_values)).._values[key] = update,
        none: () => Dict(Map.of(_values)).._values.remove(key),
      );

  Dict<Key, Value> put(Key key, Value value) => mut_array_op(key, Optional(value));

  Diff _mut_array_op_mutated(Key key, Optional<Value> update) {
    return update.cases(some: (update) {
      if (!_values.containsKey(key)) {
        return Diff(
          added: PathSet.from({
            [
              Vec<dynamic>(<dynamic>['[]', key])
            ]
          }),
          changed: PathSet.from({
            ['keys'],
            ['length'],
          }),
        );
      } else {
        return Diff(
          changed: PathSet.from({
            [
              Vec<dynamic>(<dynamic>['[]', key])
            ]
          }),
        );
      }
    }, none: () {
      if (!_values.containsKey(key)) {
        return const Diff();
      } else {
        return Diff(
          removed: PathSet.from({
            [
              Vec<dynamic>(<dynamic>['[]', key])
            ]
          }),
          changed: PathSet.from({
            ['keys'],
            ['length'],
          }),
        );
      }
    });
  }

  Dict<Key, Value> remove(Key key) {
    final newDict = Dict(Map.of(_values));
    newDict._values.remove(key);
    return newDict;
  }

  Diff _remove_mutated(Key key) {
    if (_values.containsKey(key)) {
      return Diff(
        removed: PathSet.from({
          [key]
        }),
        changed: PathSet.from({
          ['keys'],
          ['length']
        }),
      );
    } else {
      return const Diff();
    }
  }

  @override
  Iterator<MapEntry<Key, Value>> get iterator => _values.entries.iterator;

  @override
  Iterable<MapEntry<Key, Value>> get entries => this;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('{');
    for (final entry in entries) {
      buffer.write('${entry.key}: ${entry.value}, ');
    }
    buffer.write('}');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (other is! Dict<Key, Value>) return false;
    if (other.length != length) return false;
    for (final pair in zip(this, other)) {
      if (pair.first.key != pair.second.key || pair.first.value != pair.second.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => hash(this);
}
