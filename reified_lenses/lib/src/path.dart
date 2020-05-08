class Path<E> {
  final Path<E> _prev;
  final E _elem;

  const Path([this._elem, this._prev]);

  Path<E> operator +(Path<E> other) {
    if (other.isSingleton) return Path(other._elem, this);
    if (other.isEmpty) return this;
    return Path(other._elem, this + other._prev);
  }

  bool get isEmpty => _elem == null;
  bool get isSingleton => _prev == null;

  Path<E> _reverse() {
    if (this.isEmpty || this.isSingleton) return this;
    var inverted = Path(this._elem);
    var rest = this._prev;
    while (!rest.isEmpty) {
      inverted = Path(rest._elem, inverted);
      rest = rest._prev;
    }
    return inverted;
  }
}

class PathMap<K, V> {
  Set<V> _values = Set.identity();
  Map<K, PathMap<K, V>> _children = {};

  PathMap.empty();

  void add(Path<K> key, V value) => _add(key._reverse(), value);

  void _add(Path<K> key, V value) {
    if (key.isEmpty) {
      _values.add(value);
    } else {
      _children
          .putIfAbsent(key._elem, () => PathMap.empty())
          ._add(key._prev, value);
    }
  }

  void remove(Path<K> key, V value) => _remove(key._reverse(), value);

  void _remove(Path<K> key, V value) {
    if (key.isEmpty)
      _values.remove(value);
    else {
      _children[key._elem]?._remove(key._prev, value);
      if (_children[key._elem]?._children?.isEmpty ?? false)
        _children.remove(key._prev);
    }
  }

  Iterable<V> children([Path<K> key]) => _childrenInternal(key);

  Iterable<V> _childrenInternal([Path<K> key]) {
    if (key != null && !key.isEmpty)
      return _children[key._elem]?._childrenInternal(key._prev) ??
          Iterable.empty();

    final result = Set.of(_values);
    for (final child in _children.values) {
      result.addAll(child._childrenInternal());
    }
    return result;
  }

  Iterable<V> eachChildren(Iterable<Path<K>> paths) {
    final Set<V> result = Set.identity();
    for (final path in paths) result.addAll(this.children(path));
    return result;
  }

  Iterable<V> operator [](Path<K> key) => _getInternal(key._reverse());

  Iterable<V> _getInternal(Path<K> key) {
    if (key.isEmpty) return _values;
    if (_children.containsKey(key._elem))
      return _children[key._elem]._getInternal(key);
    return Iterable.empty();
  }
}
