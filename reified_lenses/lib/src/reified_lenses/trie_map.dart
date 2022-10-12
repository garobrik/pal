import 'package:meta/meta.dart';
import 'package:reified_lenses/src/functional/string_ctx.dart';
import 'package:reified_lenses/src/functional/vec.dart';

@immutable
class TrieMap<K, V> extends Iterable<V> {
  final V? _value;
  final Map<K, TrieMap<K, V>> _children;

  const TrieMap.empty()
      : _value = null,
        _children = const {};
  const TrieMap(this._value, this._children);

  factory TrieMap.from(Map<Vec<K>, V> map) {
    var result = TrieMap<K, V>.empty();
    for (var entry in map.entries) {
      result = result.set(entry.key, entry.value);
    }
    return result;
  }

  TrieMap<K, V> update(Vec<K> key, V? Function(V?) updateFn) {
    if (key.isEmpty) {
      return TrieMap(updateFn(_value), _children);
    } else {
      final newChildren = <K, TrieMap<K, V>>{
        for (final childEntry in _children.entries) childEntry.key: childEntry.value
      };
      newChildren[key.first] =
          (newChildren[key.first] ?? TrieMap.empty()).update(key.sublist(1), updateFn);
      if (newChildren[key.first]?.isEmpty ?? true) {
        newChildren.remove(key.first);
      }
      return TrieMap(_value, newChildren);
    }
  }

  TrieMap<K, V> set(Vec<K> key, V value) {
    return update(key, (_) => value);
  }

  TrieMap<K, V> remove(Vec<K> key) => update(key, (_) => null);

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

  TrieMap<K, V> prepend(Vec<K> key) {
    if (key.isEmpty || this.isEmpty) return this;
    return TrieMap<K, V>(null, <K, TrieMap<K, V>>{key.last: this})
        .prepend(key.sublist(0, key.length - 1));
  }

  TrieMap<K, V> atPrefix(Vec<K> key) {
    if (key.isEmpty) return this;
    return _children[key.first]?.atPrefix(key.sublist(1)) ?? TrieMap.empty();
  }

  Iterable<V> connectedValues(TrieSet<K> values) sync* {
    if (values.isEmpty) return;
    if (values._wrapped._value ?? false) {
      yield* children();
      return;
    }

    if (_value != null) yield _value!;

    for (final entry in values._wrapped._children.entries) {
      yield* _children[entry.key]?.connectedValues(TrieSet._fromTrieMap(entry.value)) ?? [];
    }
  }

  Iterable<V> children([Vec<K> key = const Vec()]) sync* {
    if (key.isNotEmpty) {
      yield* _children[key.first]?.children(key.sublist(1)) ?? [];
      return;
    }

    if (_value != null) {
      yield _value!;
    }
    for (final child in _children.values) {
      yield* child.children();
    }
  }

  Iterable<V> eachChildren(Iterable<Vec<K>> keys) sync* {
    for (final key in keys) {
      yield* children(key);
    }
  }

  Iterable<MapEntry<Vec<K>, V>> entries([Vec<K> key = const Vec()]) sync* {
    if (key.isNotEmpty) {
      final entries = _children[key.first]?.entries(key.sublist(1)) ?? [];
      yield* entries.map(
        (entry) => MapEntry(Vec([key.first]).append(entry.key), entry.value),
      );
      return;
    }

    if (_value != null) {
      yield MapEntry(const Vec(), _value as V);
    }
    for (final childEntry in _children.entries) {
      yield* childEntry.value.entries().map(
            (entry) => MapEntry(Vec([childEntry.key]).append(entry.key), entry.value),
          );
    }
  }

  Iterable<Vec<K>> keys([Vec<K> key = const Vec()]) sync* {
    if (key.isNotEmpty) {
      final keys = _children[key.first]?.keys(key.sublist(1)) ?? [];
      yield* keys.map(
        (childKey) => Vec([key.first]).append(childKey),
      );
      return;
    }

    if (_value != null) {
      yield const Vec();
    }
    for (final entry in _children.entries) {
      yield* entry.value.keys().map(
            (childKey) => Vec([entry.key]).append(childKey),
          );
    }
  }

  V? operator [](Vec<K> key) {
    if (key.isEmpty) return _value;
    return _children[key.first]?[key.sublist(1)];
  }

  @override
  Iterator<V> get iterator => children().iterator;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('TrieMap(');
    if (_value != null) {
      buffer.writeln('  $_value');
    }
    _writeString(buffer, 2);
    buffer.writeln(')');
    return buffer.toString();
  }

  void _writeString(StringBuffer buffer, [int indent = 0]) {
    for (final child in _children.entries) {
      buffer.write(' ' * indent);
      buffer.write('${child.key}:');
      if (child.value._value != null) {
        buffer.write(' ${child.value._value}');
      }
      buffer.writeln();
      child.value._writeString(buffer, indent + 2);
    }
  }
}

@immutable
class TrieMapSet<K, V> extends Iterable<V> {
  final TrieMap<K, Set<V>> _wrapped;

  const TrieMapSet.empty() : _wrapped = const TrieMap.empty();
  TrieMapSet(Set<V> values, Map<K, TrieMap<K, Set<V>>> children)
      : _wrapped = TrieMap<K, Set<V>>(values, children);
  const TrieMapSet._fromTrieMap(this._wrapped);

  factory TrieMapSet.from(Map<Vec<K>, V> map) {
    var result = TrieMapSet<K, V>.empty();
    for (var entry in map.entries) {
      result = result.add(entry.key, entry.value);
    }
    return result;
  }

  TrieMapSet<K, V> add(Vec<K> key, V value) {
    return TrieMapSet._fromTrieMap(
      TrieMap(_wrapped._value, _wrapped._children).update(
        key,
        (existing) => existing?.union({value}) ?? {value},
      ),
    );
  }

  TrieMapSet<K, V> remove(Vec<K> key, V value) {
    return TrieMapSet._fromTrieMap(
      TrieMap(_wrapped._value, _wrapped._children).update(
        key,
        (existing) {
          if (existing == null) return null;
          final removed = existing.difference({value});
          return removed.isEmpty ? null : removed;
        },
      ),
    );
  }

  TrieMapSet<K, V> union(TrieMapSet<K, V> other) {
    return TrieMapSet._fromTrieMap(
      TrieMap(_wrapped._value, _wrapped._children).merge(
        other._wrapped,
        mergeFn: (set1, set2) => set1.union(set2),
      ),
    );
  }

  TrieMapSet<K, V> prepend(Vec<K> key) {
    return TrieMapSet._fromTrieMap(TrieMap(_wrapped._value, _wrapped._children).prepend(key));
  }

  TrieMapSet<K, V> atPrefix(Vec<K> key) {
    return TrieMapSet._fromTrieMap(TrieMap(_wrapped._value, _wrapped._children).atPrefix(key));
  }

  Iterable<V> connectedValues(TrieSet<K> keys) {
    return TrieMap(_wrapped._value, _wrapped._children)
        .connectedValues(keys)
        .fold<Set<V>>(Set.identity(), (set1, set2) => set1.union(set2));
  }

  Iterable<V> children([Vec<K> key = const Vec()]) sync* {
    for (final set in TrieMap(_wrapped._value, _wrapped._children).children(key)) {
      yield* set;
    }
  }

  Iterable<V> eachChildren(Iterable<Vec<K>> keys) sync* {
    for (final key in keys) {
      yield* children(key);
    }
  }

  Iterable<MapEntry<Vec<K>, V>> entries([Vec<K> key = const Vec()]) sync* {
    for (final entry in TrieMap(_wrapped._value, _wrapped._children).entries(key)) {
      yield* entry.value.map((value) => MapEntry(entry.key, value));
    }
  }

  Iterable<Vec<K>> keys([Vec<K> key = const Vec()]) sync* {
    yield* TrieMap(_wrapped._value, _wrapped._children).keys(key);
  }

  Set<V> operator [](Vec<K> key) {
    return TrieMap(_wrapped._value, _wrapped._children)[key] ?? const {};
  }

  @override
  Iterator<V> get iterator => children().iterator;
}

@immutable
class TrieSet<K> extends Iterable<Vec<K>> with ToStringCtx {
  final TrieMap<K, bool> _wrapped;

  const TrieSet.empty() : _wrapped = const TrieMap.empty();
  const TrieSet.root() : _wrapped = const TrieMap(true, {});
  const TrieSet._fromTrieMap(this._wrapped);

  factory TrieSet.from(Set<Vec<K>> set) {
    var result = TrieSet<K>.empty();
    for (var key in set) {
      result = result.add(key.isEmpty ? const Vec() : key);
    }
    return result;
  }

  TrieSet<K> add(Vec<K> key) {
    return TrieSet._fromTrieMap(TrieMap(_wrapped._value, _wrapped._children).set(key, true));
  }

  TrieSet<K> remove(Vec<K> key) {
    return TrieSet._fromTrieMap(TrieMap(_wrapped._value, _wrapped._children).remove(key));
  }

  TrieSet<K> union(TrieSet<K> other) {
    return TrieSet._fromTrieMap(TrieMap(_wrapped._value, _wrapped._children).merge(other._wrapped));
  }

  TrieSet<K> prepend(Vec<K> key) {
    return TrieSet._fromTrieMap(TrieMap(_wrapped._value, _wrapped._children).prepend(key));
  }

  TrieSet<K> atPrefix(Vec<K> key) {
    return TrieSet._fromTrieMap(TrieMap(_wrapped._value, _wrapped._children).atPrefix(key));
  }

  Iterable<Vec<K>> values([Vec<K> key = const Vec()]) sync* {
    yield* TrieMap(_wrapped._value, _wrapped._children).keys(key);
  }

  bool get containsRoot => _wrapped._value == true;

  @override
  Iterator<Vec<K>> get iterator => values().iterator;

  @override
  void doStringCtx(StringBuffer buffer, int leading) {
    buffer.writeln('{');
    for (final path in this) {
      path.doStringCtx(buffer, leading + 2);
    }
    buffer.write('}'.padLeft(leading + 1));
  }
}
