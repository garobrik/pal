import 'package:meta/meta.dart';
import 'zoom.dart';
import 'reified_lenses.dart';
import 'path.dart';

class ListenableState<T> {
  T _state;
  PathMap<Object, void Function()> _listenables = PathMap.empty();

  ListenableState(this._state);

  Zoom<Cursor, T> get cursor => _CursorImpl(this, Lens.identity());

  T get bareState => _state;

  S get<S>(Zoom<Getter<T>, S> getter) {
    return getter.get(_state);
  }

  S getAndListen<S>(Zoom<Getter<T>, S> getter, void Function() callback) {
    final result = getter.getResult(_state);
    _listenables.add(result.path, callback);
    return result.value;
  }

  void mutAndNotify<S>(Zoom<Mutater<T>, S> mutater, S Function(S s) mutation) {
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

abstract class CursorInterface<C extends Cursor, S>
    with GetCursorInterface<C, S>, MutCursorInterface<C, S> {
  Zoom<Lens<dynamic>, S> get lens;

  @override
  Zoom<Getter<dynamic>, S> get getter => lens;

  @override
  Zoom<Mutater<dynamic>, S> get mutater => lens;
}

class Cursor implements GetCursor, MutCursor {}

class _CursorImpl<S> extends CursorInterface<Cursor, S> {
  final ListenableState<dynamic> state;
  final Zoom<Lens<dynamic>, S> lens;
  _CursorImpl(this.state, this.lens);

  @override
  Zoom<Cursor, S2> then<S2>(Zoom<Lens<S>, S2> lens) {
    return _CursorImpl(this.state, this.lens.then(lens));
  }
}

abstract class GetCursorInterface<C extends GetCursor, S>
    implements ThenGetInterface<C, GetCursor, S>, ThenLensInterface<C, S> {
  @protected
  ListenableState<dynamic> get state;
  @protected
  Zoom<Getter<dynamic>, S> get getter;

  void listen(void Function() callback) {
    state.getAndListen(getter, callback);
  }

  S get([void Function() callback]) {
    return callback == null
        ? state.get(getter)
        : state.getAndListen(getter, callback);
  }

  @override
  Zoom<GetCursor, S2> thenGet<S2>(Zoom<Getter<S>, S2> getter) {
    return _GetCursorImpl(state, this.getter.thenGet(getter));
  }
}

class _GetCursorImpl<S> with GetCursorInterface<GetCursor, S> {
  final ListenableState<dynamic> state;
  final Zoom<Getter<dynamic>, S> getter;

  _GetCursorImpl(this.state, this.getter);

  @override
  Zoom<GetCursor, S2> then<S2>(Zoom<Lens<S>, S2> lens) {
    return _GetCursorImpl(state, getter.then(lens));
  }
}

class GetCursor implements ThenGet<GetCursor>, ThenLens {}

extension GetCursorInterfaceExtension<S> on Zoom<GetCursor, S> {
  GetCursorInterface<GetCursor, S> get _this =>
      this as GetCursorInterface<GetCursor, S>;

  S get(void Function() callback) => _this.get(callback);
  void listen(void Function() callback) => _this.get(callback);
}

abstract class MutCursorInterface<C extends MutCursor, S>
    implements ThenMutInterface<C, MutCursor, S>, ThenLensInterface<C, S> {
  @protected
  ListenableState<dynamic> get state;
  @protected
  Zoom<Mutater<dynamic>, S> get mutater;

  void mut(S Function(S) f) {
    state.mutAndNotify(mutater, f);
  }

  void set(S s) {
    state.setAndNotify(mutater.setter, s);
  }

  @override
  Zoom<MutCursor, S2> thenMut<S2>(Zoom<Mutater<S>, S2> mutater) {
    return _MutCursorImpl(state, this.mutater.thenMut(mutater));
  }
}

extension MutCursorInterfaceExtension<S> on Zoom<MutCursor, S> {
  MutCursorInterface<MutCursor, S> get _this =>
      this as MutCursorInterface<MutCursor, S>;

  void mut(S Function(S) f) => _this.mut(f);

  void set(S s) => _this.set(s);
}

class MutCursor implements ThenMut<MutCursor>, ThenLens {}

class _MutCursorImpl<S> extends MutCursorInterface<MutCursor, S> {
  final ListenableState<dynamic> state;
  final Zoom<Mutater<dynamic>, S> mutater;

  _MutCursorImpl(this.state, this.mutater);

  @override
  Zoom<MutCursor, S2> then<S2>(Zoom<Lens<S>, S2> lens) {
    return _MutCursorImpl(state, mutater.then(lens));
  }
}
