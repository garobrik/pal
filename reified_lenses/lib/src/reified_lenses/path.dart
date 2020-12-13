class Path<E> {
  final Path<E>? _prev;
  final E? _elem;

  const Path(this._elem, this._prev)
      : assert(_elem != null),
        assert(_prev != null);
  const Path.singleton(this._elem)
      : assert(_elem != null),
        _prev = const Path.empty();
  const Path.empty()
      : _prev = null,
        _elem = null;

  Path<E> operator +(Path<E> other) {
    if (other.isSingleton) return Path(other._elem, this);
    if (other.isEmpty) return this;
    return Path(other._elem, this + other._prev!);
  }

  bool get isEmpty => _elem == null;
  bool get isSingleton => _prev?.isEmpty ?? false;

  Path<E> _reverse() {
    if (isEmpty || isSingleton) return this;
    var inverted = Path.singleton(_elem);
    var rest = _prev;
    while (!rest!.isEmpty) {
      inverted = Path(rest._elem, inverted);
      rest = rest._prev;
    }
    return inverted;
  }

  E get first {
    assert(!isEmpty);
    return _elem!;
  }

  Path<E> get rest {
    assert(!isEmpty);
    return _prev!;
  }
}

class PathMap<K, V> {
  final Set<V> _values = Set.identity();
  final Map<K, PathMap<K, V>> _children = {};

  PathMap.empty();

  void add(Path<K> key, V value) => _add(key._reverse(), value);

  void _add(Path<K> key, V value) {
    if (key.isEmpty) {
      _values.add(value);
    } else {
      _children
          .putIfAbsent(key.first, () => PathMap.empty())
          ._add(key.rest, value);
    }
  }

  void remove(Path<K> key, V value) => _remove(key._reverse(), value);

  void _remove(Path<K> key, V value) {
    if (key.isEmpty) {
      _values.remove(value);
    } else {
      _children[key.first]?._remove(key.rest, value);
      if (_children[key.first]?._children.isEmpty ?? false) {
        _children.remove(key._prev);
      }
    }
  }

  Iterable<V> children([Path<K> key = const Path.empty()]) => _childrenInternal(key);

  Iterable<V> _childrenInternal([Path<K> key = const Path.empty()]) {
    if (!key.isEmpty) {
      return _children[key.first]?._childrenInternal(key.rest) ??
          Iterable.empty();
    }

    final result = Set.of(_values);
    for (final child in _children.values) {
      result.addAll(child._childrenInternal());
    }
    return result;
  }

  Iterable<V> eachChildren(Iterable<Path<K>> paths) {
    final Set<V> result = Set.identity();
    for (final path in paths) {
      result.addAll(children(path));
    }
    return result;
  }

  Iterable<V> operator [](Path<K> key) => _getInternal(key._reverse());

  Iterable<V> _getInternal(Path<K> key) {
    if (key.isEmpty) return _values;
    return _children[key.first]?._getInternal(key.rest) ?? const [];
  }
}
