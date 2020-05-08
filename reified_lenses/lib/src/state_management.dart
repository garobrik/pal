import 'package:meta/meta.dart';
import 'zoom.dart';
import 'reified_lenses.dart';
import 'path.dart';

class State<T> {
  T _state;
  PathMap<Object, void Function()> _listenables;

  State(this._state);

  T get bareState => _state;

  S getAndListen<S>(Zoom<Getter<T>, S> getter, void Function() callback) {
    final result = getter.getResult(_state);
    _listenables.add(result.path, callback);
    return result.value;
  }

  void mutAndNotify<S>(Zoom<Mutater<T>, S> mutater, S Function(S s) mutation) {
    transformAndNotify((state) => mutater.mutResult(state, mutation));
  }

  void setAndNotify<S>(SetterF<T, S> setter, S newValue) {
    transformAndNotify((state) => setter(state, newValue)); //
  }

  void transformAndNotify(TransformF<T> transform) {
    final result = transform(_state);
    _state = result.value;
    _listenables.eachChildren(result.mutated).forEach((f) => f());
  }

  Type get type => T;
}

abstract class CursorInterface<S>
    with GetCursorInterface<Cursor, S>, MutCursorInterface<Cursor, S> {
  final State<dynamic> _state;
  CursorInterface(this._state);

  Zoom<Lens<dynamic>, S> get lens;

  @override
  Zoom<Getter<dynamic>, S> get getter => lens;

  @override
  Zoom<Mutater<dynamic>, S> get mutater => lens;

  @override
  State get state => _state;

  @override
  Zoom<Cursor, S2> then<S2>(Zoom<Lens<S>, S2> lens) {
    // TODO: implement then
    return null;
  }

  @override
  Zoom<MutCursor, S2> thenMut<S2>(Zoom<Mutater<S>, S2> mutF) {
    // TODO: implement thenMut
    return null;
  }
}

class Cursor implements GetCursor, MutCursor {}

abstract class GetCursorInterface<C extends GetCursor, S>
    implements ThenGetInterface<C, GetCursor, S>, ThenLensInterface<C, S> {
  @protected
  State<dynamic> get state;
  @protected
  Zoom<Getter<dynamic>, S> get getter;

  void listen(void Function() callback) {
    state.getAndListen(getter, callback);
  }

  S get(void Function() callback) {
    return state.getAndListen(getter, callback);
  }

  @override
  Zoom<GetCursor, S2> thenGet<S2>(Zoom<Getter<S>, S2> getter) {
    return GetCursor.mk<dynamic, S2>(state, this.getter.thenGet(getter));
  }
}

class _GetCursorImpl<S> with GetCursorInterface<GetCursor, S> {
  final State<dynamic> _state;
  final Zoom<Getter<dynamic>, S> _getter;

  @override
  Zoom<Getter<dynamic>, S> get getter => _getter;

  @override
  State get state => _state;

  _GetCursorImpl(this._state, this._getter);

  @override
  Zoom<GetCursor, S2> then<S2>(Zoom<Lens<S>, S2> lens) {
    return GetCursor.mk<dynamic, S2>(_state, this.getter.then(lens));
  }
}

class GetCursor implements ThenGet<GetCursor>, ThenLens {
  static Zoom<GetCursor, S> mk<T, S>(State<T> state,
          [Zoom<Getter<T>, S> getter]) =>
      _GetCursorImpl(state, getter == null ? Getter.identity() : getter);
}

extension GetCursorInterfaceExtension<S> on Zoom<GetCursor, S> {
  GetCursorInterface<GetCursor, S> get _this => this as GetCursorInterface<GetCursor, S>;

  S get(void Function() callback) => _this.get(callback);
  void listen(void Function() callback) => _this.get(callback);
}

abstract class MutCursorInterface<C extends MutCursor, S>
    implements ThenMutInterface<C, MutCursor, S>, ThenLensInterface<C, S> {
  @protected
  State<dynamic> get state;
  @protected
  Zoom<Mutater<dynamic>, S> get mutater;

  void mut(S Function(S) f) {
    state.mutAndNotify(mutater, f);
  }

  void set(S s) {
    state.setAndNotify(mutater.setter, s);
  }
}

class MutCursor implements ThenMut<MutCursor>, ThenLens {}
