import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'map.g.dart';

@immutable
@reify
class Dict<Key extends Object, Value> extends Iterable<MapEntry<Key, Value>> {
  @skip
  final SplayTreeMap<Key, Value> _values;
  Dict([Map<Key, Value>? values]) : _values = values is SplayTreeMap<Key, Value> ? values : SplayTreeMap.of(values ?? {});

  @override
  @reify
  int get length => _values.length;

  @reify
  Value? operator [](Key key) => _values[key];
  Dict<Key, Value> mut_array_op(Key key, Value update) {
    final newDict = Dict(SplayTreeMap.of(_values));
    newDict._values[key] = update;
    return newDict;
  }

  Dict<Key, Value> remove(Key key) {
    final newDict = Dict(SplayTreeMap.of(_values));
    newDict._values.remove(key);
    return newDict;
  }

  TrieSet<Object> _remove_mutated(Key index) => TrieSet.from({
        [index],
      });

  @override
  Iterator<MapEntry<Key, Value>> get iterator => _values.entries.iterator;

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
