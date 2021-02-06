import 'package:meta/meta.dart';

@immutable
class TrieMap<K, V> extends Iterable<V> {
  final V? _value;
  final Map<K, TrieMap<K, V>> _children;

  const TrieMap.empty()
      : _value = null,
        _children = const {};
  const TrieMap(this._value, this._children);

  factory TrieMap.from(Map<Iterable<K>, V> map) {
    var result = TrieMap<K, V>.empty();
    for (var entry in map.entries) {
      result = result.set(entry.key, entry.value);
    }
    return result;
  }

  TrieMap<K, V> update(Iterable<K> key, V? Function(V?) updateFn) {
    if (key.isEmpty) {
      return TrieMap(updateFn(_value), _children);
    } else {
      final newChildren = <K, TrieMap<K, V>>{};
      newChildren.addAll(_children);
      newChildren[key.first] = (newChildren[key.first] ?? TrieMap.empty())
          .update(key.skip(1), updateFn);
      if (newChildren[key.first]?.isEmpty ?? true) {
        newChildren.remove(key.first);
      }
      return TrieMap(_value, newChildren);
    }
  }

  TrieMap<K, V> set(Iterable<K> key, V value) => update(key, (_) => value);

  TrieMap<K, V> remove(Iterable<K> key) => update(key, (_) => null);

  TrieMap<K, V> merge(TrieMap<K, V> other, {V? Function(V, V)? mergeFn}) {
    var result = this;
    for (final entry in other.entries()) {
      result = result.update(entry.key, (value) {
        if (value == null || mergeFn == null) return entry.value;
        return mergeFn(value, entry.value);
      });
    }
    return result;
  }

  TrieMap<K, V> prepend(Iterable<K> key) {
    if (key.isEmpty) return this;
    return TrieMap<K, V>(null, <K, TrieMap<K, V>>{key.last: this})
        .prepend(key.take(key.length - 1));
  }

  Iterable<V> children([Iterable<K> key = const Iterable.empty()]) sync* {
    if (key.isNotEmpty) {
      yield* _children[key.first]?.children(key.skip(1)) ?? <V>[];
      return;
    }

    if (_value != null) {
      yield _value!;
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

    if (_value != null) {
      yield MapEntry(Iterable.empty(), _value!);
    }
    for (final childEntry in _children.entries) {
      yield* childEntry.value.entries().map(
            (entry) =>
                MapEntry([childEntry.key].followedBy(entry.key), entry.value),
          );
    }
  }

  Iterable<Iterable<K>> keys([Iterable<K> key = const Iterable.empty()]) sync* {
    if (key.isNotEmpty) {
      final keys = _children[key.first]?.keys(key.skip(1)) ?? [];
      yield* keys.map(
        (childKey) => [key.first].followedBy(childKey),
      );
      return;
    }

    if (_value != null) {
      yield Iterable.empty();
    }
    for (final entry in _children.entries) {
      yield* entry.value.keys().map(
            (childKey) => [entry.key].followedBy(childKey),
          );
    }
  }

  V? operator [](Iterable<K> key) {
    if (key.isEmpty) return _value;
    return _children[key.first]?[key.skip(1)];
  }

  @override
  Iterator<V> get iterator => children().iterator;
}

@immutable
class TrieMapSet<K, V> extends Iterable<V> {
  final TrieMap<K, Set<V>> _wrapped;

  const TrieMapSet.empty() : _wrapped = const TrieMap.empty();
  TrieMapSet(Set<V> values, Map<K, TrieMap<K, Set<V>>> children)
      : _wrapped = TrieMap<K, Set<V>>(values, children);
  const TrieMapSet._fromTrieMap(this._wrapped);

  factory TrieMapSet.from(Map<Iterable<K>, V> map) {
    var result = TrieMapSet<K, V>.empty();
    for (var entry in map.entries) {
      result = result.add(entry.key, entry.value);
    }
    return result;
  }

  TrieMapSet<K, V> add(Iterable<K> key, V value) {
    return TrieMapSet._fromTrieMap(
      _wrapped.update(
        key,
        (existing) => existing?.union({value}) ?? {value},
      ),
    );
  }

  TrieMapSet<K, V> remove(Iterable<K> key, V value) {
    return TrieMapSet._fromTrieMap(
      _wrapped.update(
        key,
        (existing) {
          if (existing == null) return null;
          final removed = existing.difference({value});
          return removed.isEmpty ? null : removed;
        },
      ),
    );
  }

  TrieMapSet<K, V> merge(TrieMapSet<K, V> other) {
    return TrieMapSet._fromTrieMap(
      _wrapped.merge(
        other._wrapped,
        mergeFn: (set1, set2) => set1.union(set2),
      ),
    );
  }

  TrieMapSet<K, V> prepend(Iterable<K> key) {
    return TrieMapSet._fromTrieMap(_wrapped.prepend(key));
  }

  Iterable<V> children([Iterable<K> key = const Iterable.empty()]) sync* {
    for (final set in _wrapped.children(key)) {
      yield* set;
    }
  }

  Iterable<V> eachChildren(Iterable<Iterable<K>> keys) sync* {
    for (final key in keys) {
      yield* children(key);
    }
  }

  Iterable<MapEntry<Iterable<K>, V>> entries(
      [Iterable<K> key = const Iterable.empty()]) sync* {
    for (final entry in _wrapped.entries(key)) {
      yield* entry.value.map((value) => MapEntry(entry.key, value));
    }
  }

  Iterable<Iterable<K>> keys([Iterable<K> key = const Iterable.empty()]) sync* {
    yield* _wrapped.keys(key);
  }

  Set<V> operator [](Iterable<K> key) {
    return _wrapped[key] ?? const {};
  }

  @override
  Iterator<V> get iterator => children().iterator;
}

@immutable
class TrieSet<K> extends Iterable<Iterable<K>> {
  final TrieMap<K, bool> _wrapped;

  const TrieSet.empty() : _wrapped = const TrieMap.empty();
  const TrieSet._fromTrieMap(this._wrapped);

  factory TrieSet.from(Set<Iterable<K>> set) {
    var result = TrieSet<K>.empty();
    for (var key in set) {
      result = result.add(key);
    }
    return result;
  }

  TrieSet<K> add(Iterable<K> key) {
    return TrieSet._fromTrieMap(_wrapped.set(key, true));
  }

  TrieSet<K> remove(Iterable<K> key) {
    return TrieSet._fromTrieMap(_wrapped.remove(key));
  }

  TrieSet<K> union(TrieSet<K> other) {
    return TrieSet._fromTrieMap(_wrapped.merge(other._wrapped));
  }

  TrieSet<K> prepend(Iterable<K> key) {
    return TrieSet._fromTrieMap(_wrapped.prepend(key));
  }

  Iterable<Iterable<K>> values([Iterable<K> key = const Iterable.empty()]) sync* {
    yield* _wrapped.keys(key);
  }

  @override
  Iterator<Iterable<K>> get iterator => values().iterator;
}
