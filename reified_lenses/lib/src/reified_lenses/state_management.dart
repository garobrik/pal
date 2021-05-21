import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';
import 'reified_lenses.dart';
import 'trie_map.dart';

abstract class GetCursor<S> {
  const factory GetCursor(S state) = _GetCursorImpl;

  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter);

  GetCursor<S1> then<S1>(Lens<S, S1> getter) => thenGet(getter);

  S get get;

  GetCursor<S> withCallback<F extends CursorCallback>(F callback);

  GetCursor<S1> cast<S1>() => thenGet(Getter<S, S1>.mkCast());

  @override
  String toString() => 'GetCursor($get)';
}

abstract class Cursor<S> implements GetCursor<S> {
  factory Cursor(S state) => _CursorImpl(_ListenableState(state), Lens.identity(), {});

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens);

  void mut(S Function(S) f) => mutResult((s) => DiffResult.allChanged(f(s)));
  void mutResult(DiffResult<S> Function(S) f);
  void set(S s) => mut((_) => s);

  @override
  Cursor<S1> cast<S1>() => then(Lens<S, S1>.mkCast());

  @override
  Cursor<S> withCallback<F extends CursorCallback>(F callback);

  T atomically<T>(T Function(Cursor<S>) f);

  @override
  String toString() => 'Cursor($get)';
}

class _ListenableState<T> {
  T _state;
  TrieMapSet<Object, void Function()> _listenables = TrieMapSet.empty();

  _ListenableState(this._state);

  T get bareState => _state;

  void listen(TrieSet<Object> paths, Iterable<CursorCallback> callbacks) {
    paths.forEach((path) {
      callbacks.forEach((callback) {
        _listenables = _listenables.add(path, callback.onChanged);
        callback.onGet(
          WithDisposal(
            () {
              _listenables = _listenables.remove(path, callback.onChanged);
            },
            path,
          ),
        );
      });
    });
  }

  PathResult<S> getResultAndListen<S>(
    Getter<T, S> getter,
    Iterable<CursorCallback> callbacks,
  ) {
    final result = getter.get(_state);
    listen(TrieSet.from({getter.path}), callbacks);
    return PathResult(result, getter.path);
  }

  DiffResult<T> transformAndNotify(DiffResult<T> Function(T) transform) {
    final result = transform(_state);
    _state = result.value;
    _listenables.eachChildren(result.diff.changed.values()).forEach((f) => f());
    return result;
  }
}

@immutable
class WithDisposal<T> {
  final void Function() dispose;
  final T value;

  const WithDisposal(this.dispose, this.value);
}

@immutable
class _CursorImpl<T, S> with Cursor<S> {
  final _ListenableState<T> state;
  final Lens<T, S> lens;
  final Map<Type, CursorCallback> callbacks;

  _CursorImpl(this.state, this.lens, this.callbacks);

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens) {
    return _CursorImpl(state, this.lens.then(lens), callbacks);
  }

  @override
  GetCursor<S2> thenGet<S2>(Getter<S, S2> getter) =>
      _CursorImpl(state, this.lens.then(Lens(getter.path, getter.get, (s, f) => s)), callbacks);

  @override
  Cursor<S> withCallback<F extends CursorCallback>(F callback) {
    final newCallbacks = <Type, CursorCallback>{};
    newCallbacks.addAll(callbacks);
    newCallbacks[callback.runtimeType] = callback;
    return _CursorImpl(state, lens, newCallbacks);
  }

  @override
  S get get => state.getResultAndListen(lens, callbacks.values).value;

  @override
  void mutResult(DiffResult<S> Function(S) f) {
    final result = state.transformAndNotify((t) => lens.mutDiff(t, f));
    callbacks.values.forEach((callback) => callback.onMut(result));
  }

  @override
  V atomically<V>(V Function(Cursor<S> p1) f) {
    final bareCursor = Cursor(lens.get(state.bareState));
    final actionLogger = _LoggingCursorCallback();
    final loggedCursor = bareCursor.withCallback(actionLogger);
    final result = f(loggedCursor);
    state.listen(actionLogger.gotten, callbacks.values);

    mutResult(
      (_) => DiffResult(
        loggedCursor.get,
        actionLogger.diff,
      ),
    );
    return result;
  }

  @override
  String toString() => 'Cursor($get)';
}

class _LoggingCursorCallback extends CursorCallback {
  Diff diff = Diff();
  PathSet gotten = PathSet.empty();

  @override
  void onGet(WithDisposal<Path> result) {
    result.dispose();
    gotten = gotten.add(result.value);
  }

  @override
  void onMut<S>(DiffResult<S> result) {
    diff = diff.union(result.diff);
  }
}

abstract class CursorCallback {
  void onChanged() {}
  void onGet(WithDisposal<Path> result) => result.dispose();
  void onMut<S>(DiffResult<S> result) {}
}

extension GetCursorListenExtension<S> on GetCursor<S> {
  WithDisposal<S> getAndListen(void Function() callback) {
    void Function()? dispose;
    final s = this
        .withCallback(
          _GetCursorListenExtensionCallback(
            callback,
            (result) => dispose = result.dispose,
          ),
        )
        .get;
    return WithDisposal(dispose!, s);
  }

  void Function() listen(void Function() callback) => getAndListen(callback).dispose;
}

class _GetCursorListenExtensionCallback extends CursorCallback {
  final void Function() onChangedCallback;
  final void Function(WithDisposal<Path> result) onGetCallback;

  _GetCursorListenExtensionCallback(this.onChangedCallback, this.onGetCallback);

  @override
  void onChanged() => onChangedCallback();

  @override
  void onGet(WithDisposal<Iterable<Object>> result) => onGetCallback(result);
}

@immutable
class _GetCursorImpl<S> with GetCursor<S> {
  final S state;

  const _GetCursorImpl(this.state);

  @override
  S get get => state;

  @override
  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter) => _GetCursorImpl(getter.get(state));

  @override
  GetCursor<S> withCallback<F extends CursorCallback>(F callback) {
    return this;
  }
}

extension CursorNullability<T> on Cursor<T?> {
  Cursor<T> get nonnull => then(Lens.identity<T?>().nonnull);
}

extension GetCursorNullability<T> on GetCursor<T?> {
  GetCursor<T> get nonnull => then(Lens.identity<T?>().nonnull);
}
