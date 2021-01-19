import 'package:meta/meta.dart';

@immutable
class TrieMap<K, V> extends Iterable<V> {
  final Set<V> _values;
  final Map<K, TrieMap<K, V>> _children;

  const TrieMap.empty()
      : _values = const {},
        _children = const {};
  const TrieMap(this._values, this._children);

  TrieMap<K, V> add(Iterable<K> key, V value) {
    if (key.isEmpty) {
      return TrieMap(<V>{value}.union(_values), _children);
    } else {
      final newChildren = <K, TrieMap<K, V>>{};
      newChildren.addAll(_children);
      newChildren[key.first] =
          (newChildren[key.first] ?? TrieMap.empty()).add(key.skip(1), value);
      return TrieMap(_values, newChildren);
    }
  }

  TrieMap<K, V> remove(Iterable<K> key, V value) {
    if (key.isEmpty) {
      return TrieMap(_values.difference({value}), _children);
    } else {
      final newChildren = <K, TrieMap<K, V>>{};
      newChildren.addAll(_children);
      newChildren[key.first] = (newChildren[key.first] ?? TrieMap.empty())
          .remove(key.skip(1), value);
      if (newChildren[key.first]?.isEmpty ?? true) {
        newChildren.remove(key.first);
      }
      return TrieMap(_values, newChildren);
    }
  }

  TrieMap<K, V> merge(TrieMap<K, V> other) {
    var result = this;
    for (final entry in other.entries()) {
      result = result.add(entry.key, entry.value);
    }
    return result;
  }

  TrieMap<K, V> prepend(Iterable<K> key) {
    if (key.isEmpty) return this;
    return TrieMap(<V>{}, <K, TrieMap<K, V>>{key.last: this})
        .prepend(key.take(key.length - 1));
  }

  Iterable<V> children([Iterable<K> key = const Iterable.empty()]) sync* {
    if (key.isNotEmpty) {
      yield* _children[key.first]?.children(key.skip(1)) ?? <V>[];
      return;
    }

    for (final result in _values) {
      yield result;
    }
    for (final child in _children.values) {
      yield* child.children();
    }
  }

  Iterable<V> eachChildren(Iterable<Iterable<K>> keys) sync* {
    for (final key in keys) {
      yield* children(key);
    }
  }

  Iterable<MapEntry<Iterable<K>, V>> entries(
      [Iterable<K> key = const Iterable.empty()]) sync* {
    if (key.isNotEmpty) {
      final entries = _children[key.first]?.entries(key.skip(1)) ?? [];
      yield* entries.map(
        (entry) => MapEntry([key.first].followedBy(entry.key), entry.value),
      );
      return;
    }

    for (final result in _values) {
      yield MapEntry(Iterable.empty(), result);
    }
    for (final childEntry in _children.entries) {
      yield* childEntry.value.entries().map(
            (entry) =>
                MapEntry([childEntry.key].followedBy(entry.key), entry.value),
          );
    }
  }

  Iterable<V> operator [](Iterable<K> key) {
    if (key.isEmpty) return _values;
    return _children[key.first]?[key.skip(1)] ?? const [];
  }

  @override
  Iterator<V> get iterator => children().iterator;
}
