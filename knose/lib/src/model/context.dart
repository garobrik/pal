import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

class Ctx {
  final Dict<Type, Object> _elements;

  const Ctx() : this._elements = const Dict();
  const Ctx._(this._elements);

  Ctx withElement<T extends CtxElement>(T element) => Ctx._(_elements.put(T, element));
  Ctx removeElement<T extends CtxElement>() => Ctx._(_elements.remove(T));
  T? get<T extends CtxElement>() => _elements[T].unwrap as T?;
  Iterable<T> ofType<T extends CtxElement>() sync* {
    for (final entry in _elements.entries) {
      if (entry.value is T) {
        yield entry.value as T;
      }
    }
  }
}

abstract class CtxElement {}
