class Ctx {
  final Map<Type, Object> _elements;

  const Ctx._(this._elements);

  static const empty = Ctx._({});

  Ctx withElement<T extends CtxElement>(T element) => Ctx._(Map.of(_elements)..[T] = element);
  Ctx removeElement<T extends CtxElement>() => Ctx._(Map.of(_elements)..remove(T));
  T? get<T extends CtxElement>() => _elements[T] as T?;
  Iterable<T> ofType<T extends CtxElement>() sync* {
    for (final entry in _elements.entries) {
      if (entry.value is T) {
        yield entry.value as T;
      }
    }
  }
}

abstract class CtxElement {
  const CtxElement();
}
