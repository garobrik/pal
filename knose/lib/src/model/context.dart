import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart';

class Ctx {
  final Dict<Type, Object> _elements;
  final Cursor<State> state;

  const Ctx(this.state) : this._elements = const Dict();
  const Ctx._(this.state, this._elements);

  Ctx withElement<T extends CtxElement>(T element) =>
      Ctx._(state, _elements.put(T, element));
  Ctx removeElement<T extends CtxElement>() => Ctx._(state, _elements.remove(T));
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
