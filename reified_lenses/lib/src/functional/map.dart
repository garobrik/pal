import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'map.g.dart';

@immutable
@ReifiedLens(type: ReifiedKind.Map)
class Dict<Key extends Object, Value> extends Iterable<MapEntry<Key, Value>> with _DictMixin<Key, Value> {
  @skip
  final SplayTreeMap<Key, Value> _values;

  Dict([Map<Key, Value> values = const {}])
      : _values = values is SplayTreeMap<Key, Value> ? values : SplayTreeMap.of(values);

  @override
  @reify
  int get length => _values.length;

  @reify
  Iterable<Key> get keys => _values.keys;

  @reify
  Value? operator [](Key key) => _values[key];
  Dict<Key, Value> mut_array_op(Key key, Value? update) => update != null
      ? (Dict(SplayTreeMap.of(_values)).._values[key] = update)
      : (Dict(SplayTreeMap.of(_values)).._values.remove(key));

  Diff _mut_array_op_mutated(Key key, Value? update) {
    if (update != null) {
      if (!_values.containsKey(key)) {
        return Diff(
          added: PathSet.from({
            [key]
          }),
          changed: PathSet.from({
            ['keys'],
            ['length'],
          }),
        );
      } else {
        return Diff(
          changed: PathSet.from({
            [key]
          }),
        );
      }
    } else {
      if (!_values.containsKey(key)) {
        return const Diff();
      } else {
        return Diff(
          removed: PathSet.from({
            [key]
          }),
          changed: PathSet.from({
            ['keys'],
            ['length'],
          }),
        );
      }
    }
  }

  Dict<Key, Value> remove(Key key) {
    final newDict = Dict(SplayTreeMap.of(_values));
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

  Iterable<MapEntry<Key, Value>> get entries => this;

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
