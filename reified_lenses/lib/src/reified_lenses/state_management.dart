import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';
import 'reified_lenses.dart';
import 'trie_map.dart';

class ListenableState<T> {
  T _state;
  TrieMap<Object, void Function()> _listenables = TrieMap.empty();

  ListenableState(this._state);

  Cursor<T> get cursor => _CursorImpl(this, Lens.identity(), {});

  T get bareState => _state;

  Pair<Iterable<void Function()>, GetResult<S>> getResultAndListen<S>(
      Getter<T, S> getter, Iterable<void Function()> callbacks) {
    final result = getter.getResult(_state);
    final disposals = callbacks.map((callback) {
      _listenables = _listenables.add(result.path, callback);
      return () {
        _listenables = _listenables.remove(result.path, callback);
      };
    });
    return Pair(disposals, result);
  }

  void mutAndNotify<S>(Mutater<T, S> mutater, S Function(S s) mutation) {
    transformAndNotify(mutater.transform(mutation));
  }

  void setAndNotify<S>(ReifiedSetterF<T, S> setter, S newValue) {
    transformAndNotify((state) => setter(state, newValue));
  }

  void transformAndNotify(ReifiedTransformF<T> transform) {
    final result = transform(_state);
    _state = result.value;
    _listenables.eachChildren(result.mutated).forEach((f) => f());
  }
}

@immutable
class WithDisposal<T> {
  final void Function() dispose;
  final T value;

  const WithDisposal(this.dispose, this.value);
}

abstract class Cursor<S> implements GetCursor<S>, MutCursor<S> {
  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens);

  @override
  GetCursor<S2> thenGet<S2>(Getter<S, S2> getter);

  @override
  MutCursor<S2> thenMut<S2>(Mutater<S, S2> mutater);

  @override
  void set(S s) => mut((_) => s);

  @override
  Cursor<S1> cast<S1>() => then(Lens.mkCast<S, S1>());
}

@immutable
class _CursorImpl<T, S> extends Cursor<S> {
  final ListenableState<T> state;
  final Lens<T, S> lens;
  final Map<Type, GetCallback> getCallbacks;

  _CursorImpl(this.state, this.lens, this.getCallbacks);

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens) {
    return _CursorImpl(state, this.lens.then(lens), getCallbacks);
  }

  @override
  void mut(S Function(S p1) f) => MutCursor.mk(state, lens).mut(f);

  @override
  void set(S s) => MutCursor.mk(state, lens).set(s);

  @override
  GetCursor<S2> thenGet<S2>(Getter<S, S2> getter) =>
      GetCursor.mk(state, lens.thenGet(getter), callbacks: getCallbacks);

  @override
  MutCursor<S2> thenMut<S2>(Mutater<S, S2> mutater) =>
      MutCursor.mk(state, lens.thenMut(mutater));

  @override
  Cursor<S> withGetCallback<F extends GetCallback>(F callback) {
    final newCallbacks = <Type, GetCallback>{};
    newCallbacks.addAll(getCallbacks);
    newCallbacks[F] = callback;
    return _CursorImpl(state, lens, newCallbacks);
  }

  @override
  S get get => GetCursor.mk(state, lens, callbacks: getCallbacks).get;

  @override
  void mutResult(ReifiedTransformF<S> f) =>
      MutCursor.mk(state, lens).mutResult(f);
}

@immutable
abstract class GetCallback {
  void onChanged();
  void onGet<S>(WithDisposal<GetResult<S>> result);
}

@immutable
abstract class GetCursor<S> implements ThenGet<S>, ThenLens<S> {
  static GetCursor<S> mk<T, S>(
    ListenableState<T> state,
    Getter<T, S> getter, {
    Map<Type, GetCallback> callbacks = const {},
  }) =>
      _GetCursorImpl(state, getter, callbacks);

  @override
  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter);

  @override
  GetCursor<S1> then<S1>(Lens<S, S1> getter) => thenGet(getter);

  S get get;

  GetCursor<S> withGetCallback<F extends GetCallback>(F callback);

  GetCursor<S1> cast<S1>() => thenGet(Getter.mkCast<S, S1>());
}

extension GetCursorListenExtension<S> on GetCursor<S> {
  WithDisposal<S> getAndListen(void Function() callback) {
    void Function()? dispose;
    final s = this
        .withGetCallback(
          _GetCursorListenExtensionCallback(
            callback,
            <S>(WithDisposal<GetResult<S>> result) => dispose = result.dispose,
          ),
        )
        .get;
    return WithDisposal(dispose!, s);
  }
}

class _GetCursorListenExtensionCallback extends GetCallback {
  final void Function() onChangedCallback;
  final void Function<S>(WithDisposal<GetResult<S>> result) onGetCallback;

  _GetCursorListenExtensionCallback(this.onChangedCallback, this.onGetCallback);

  @override
  void onChanged() => onChangedCallback();

  @override
  void onGet<S>(WithDisposal<GetResult<S>> result) => onGetCallback(result);
}

@immutable
class _GetCursorImpl<T, S> extends GetCursor<S> {
  final ListenableState<T> state;
  final Getter<T, S> getter;
  final Map<Type, GetCallback> getCallbacks;

  _GetCursorImpl(this.state, this.getter, this.getCallbacks);

  @override
  S get get {
    final disposalsAndResult = state.getResultAndListen(
        getter, getCallbacks.values.map((c) => c.onChanged));
    for (final disposalAndCallback
        in zip(disposalsAndResult.first, getCallbacks.values)) {
      disposalAndCallback.second.onGet(WithDisposal(
        disposalAndCallback.first,
        disposalsAndResult.second,
      ));
    }
    return disposalsAndResult.second.value;
  }

  @override
  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter) {
    return _GetCursorImpl(state, this.getter.thenGet(getter), getCallbacks);
  }

  @override
  GetCursor<S> withGetCallback<F extends GetCallback>(F callback) {
    final newCallbacks = <Type, GetCallback>{};
    newCallbacks.addAll(getCallbacks);
    newCallbacks[F] = callback;
    return _GetCursorImpl(state, getter, newCallbacks);
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
  MutCursor<S2> then<S2>(Lens<S, S2> lens) => thenMut(lens);

  @override
  MutCursor<S2> thenMut<S2>(Mutater<S, S2> lens);

  void mut(S Function(S) f);
  void mutResult(ReifiedTransformF<S> f);
  void set(S s) => mut((_) => s);

  MutCursor<S1> cast<S1>() => thenMut(Mutater.mkCast<S, S1>());
}

@immutable
class _MutCursorImpl<T, S> extends MutCursor<S> {
  final ListenableState<T> state;
  final Mutater<T, S> mutater;

  _MutCursorImpl(this.state, this.mutater);

  @override
  void mut(S Function(S) f) {
    state.mutAndNotify(mutater, f);
  }

  @override
  MutCursor<S2> thenMut<S2>(Mutater<S, S2> mutater) {
    return _MutCursorImpl(state, this.mutater.thenMut(mutater));
  }

  @override
  void mutResult(ReifiedTransformF<S> f) {
    state.transformAndNotify(mutater.reifiedTransform(f));
  }
}
