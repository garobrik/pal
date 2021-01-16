class TrieMap<K, V> extends Iterable<V> {
  final Set<V> _values = Set.identity();
  final Map<K, TrieMap<K, V>> _children = {};

  TrieMap.empty();

  void add(Iterable<K> key, V value) {
    if (key.isEmpty) {
      _values.add(value);
    } else {
      _children
          .putIfAbsent(key.first, () => TrieMap.empty())
          .add(key.skip(1), value);
    }
  }

  void remove(Iterable<K> key, V value) {
    if (key.isEmpty) {
      _values.remove(value);
    } else {
      _children[key.first]?.remove(key.skip(1), value);
      if (_children[key.first]?._children.isEmpty ?? false) {
        _children.remove(key.skip(1));
      }
    }
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

  Iterable<V> eachChildren(Iterable<Iterable<K>> paths) sync* {
    for (final path in paths) {
      yield* children(path);
    }
  }

  Iterable<V> operator [](Iterable<K> key) {
    if (key.isEmpty) return _values;
    return _children[key.first]?[key.skip(1)] ?? const [];
  }

  void clear() {
    _values.clear();
    _children.clear();
  }

  @override
  Iterator<V> get iterator => children().iterator;
}
