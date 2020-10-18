import 'package:meta/meta.dart';
import 'reified_lenses.dart';
import 'path.dart';

class ListenableState<T> {
  T _state;
  PathMap<Object, void Function()> _listenables = PathMap.empty();

  ListenableState(this._state);

  Cursor<T> get cursor => _CursorImpl(this, Lens.identity());

  T get bareState => _state;

  S get<S>(Getter<T, S> getter) => getter.getResult(_state).value;

  S getAndListen<S>(Getter<T, S> getter, void Function() callback) {
    final result = getter.getResult(_state);
    _listenables.add(result.path, callback);
    return result.value;
  }

  void mutAndNotify<S>(Mutater<T, S> mutater, S Function(S s) mutation) {
    transformAndNotify((state) => mutater.mutResult(state, mutation));
  }

  void setAndNotify<S>(ReifiedSetterF<T, S> setter, S newValue) {
    transformAndNotify((state) => setter(state, newValue)); //
  }

  void transformAndNotify(ReifiedTransformF<T> transform) {
    final result = transform(_state);
    _state = result.value;
    _listenables.eachChildren(result.mutated).forEach((f) => f());
  }

  Type get type => T;
}

abstract class Cursor<S> implements GetCursor<S>, MutCursor<S> {
  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens);

  @override
  GetCursor<S2> thenGet<S2>(Getter<S, S2> lens);

  @override
  MutCursor<S2> thenMut<S2>(Mutater<S, S2> lens);
}

@immutable
class _CursorImpl<T, S> extends Cursor<S> {
  final ListenableState<T> state;
  final Lens<T, S> lens;
  _CursorImpl(this.state, this.lens);

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens) {
    return _CursorImpl(this.state, this.lens.then(lens));
  }

  @override
  S get([void Function() callback]) => GetCursor.mk(state, lens).get(callback);

  @override
  void listen(void Function() callback) =>
      GetCursor.mk(state, lens).get(callback);

  @override
  void mut(S Function(S p1) f) => MutCursor.mk(state, lens).mut(f);

  @override
  void set(S s) => MutCursor.mk(state, lens).set(s);

  @override
  GetCursor<S2> thenGet<S2>(Getter<S, S2> getter) =>
      GetCursor.mk(state, lens.thenGet(getter));

  @override
  MutCursor<S2> thenMut<S2>(Mutater<S, S2> mutater) =>
      MutCursor.mk(state, lens.thenMut(mutater));
}

@immutable
abstract class GetCursor<S> implements ThenGet<S>, ThenLens<S> {
  static GetCursor<S> mk<T, S>(ListenableState<T> state, Getter<T, S> getter) =>
      _GetCursorImpl(state, getter);

  @override
  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter);

  @override
  GetCursor<S1> then<S1>(Lens<S, S1> getter);

  void listen(void Function() callback);

  S get([void Function() callback]);
}

@immutable
class _GetCursorImpl<T, S> extends GetCursor<S> {
  final ListenableState<T> state;
  final Getter<T, S> getter;

  _GetCursorImpl(this.state, this.getter);

  @override
  GetCursor<S2> then<S2>(Lens<S, S2> lens) {
    return _GetCursorImpl(state, getter.then(lens));
  }

  void listen(void Function() callback) {
    state.getAndListen(getter, callback);
  }

  S get([void Function() callback]) {
    return callback == null
        ? state.get(getter)
        : state.getAndListen(getter, callback);
  }

  @override
  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter) {
    return _GetCursorImpl(state, this.getter.thenGet(getter));
  }
}

@immutable
abstract class MutCursor<S> implements ThenMut<S>, ThenLens<S> {
  static MutCursor<S> mk<T, S>(
    ListenableState<T> state,
    Mutater<T, S> mutater,
  ) =>
      _MutCursorImpl(state, mutater);

  @override
  MutCursor<S2> then<S2>(Lens<S, S2> lens);

  @override
  MutCursor<S2> thenMut<S2>(Mutater<S, S2> lens);

  void mut(S Function(S) f);

  void set(S s);
}

@immutable
class _MutCursorImpl<T, S> extends MutCursor<S> {
  final ListenableState<T> state;
  final Mutater<T, S> mutater;

  _MutCursorImpl(this.state, this.mutater);

  void mut(S Function(S) f) {
    state.mutAndNotify(mutater, f);
  }

  void set(S s) {
    state.setAndNotify(mutater.setter, s);
  }

  @override
  MutCursor<S2> thenMut<S2>(Mutater<S, S2> mutater) {
    return _MutCursorImpl(state, this.mutater.thenMut(mutater));
  }

  @override
  MutCursor<S2> then<S2>(Lens<S, S2> lens) {
    return _MutCursorImpl(state, mutater.then(lens));
  }
}
