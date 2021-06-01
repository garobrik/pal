import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';
import 'reified_lenses.dart';

abstract class GetCursor<S> {
  const factory GetCursor(S state) = _GetCursorImpl;

  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter);

  GetCursor<S1> then<S1>(Lens<S, S1> getter) => thenGet(getter);

  S get _value;

  GetCursor<S1> cast<S1>() => thenGet(Getter<S, S1>.mkCast());

  void Function() listen(void Function(S old, S nu, Diff diff) f);

  S read(Reader r) {
    r.handleDispose(listen((_, __, ___) => r.onChanged()));
    return _value;
  }

  @override
  String toString() => 'GetCursor($_value)';
}

abstract class Reader {
  void onChanged() {}
  void handleDispose(void Function() dispose);
}

const noopReader = NoopReader();

class NoopReader with Reader {
  const NoopReader();

  @override
  void handleDispose(void Function() dispose) {
    dispose();
  }
}

abstract class Cursor<S> implements GetCursor<S> {
  factory Cursor(S state) => _CursorImpl(
        _ListenableState(state),
        Lens.identity(),
      );

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens);

  void set(S s) => mut((_) => s);
  void mut(S Function(S) f) => mutResult((s) => DiffResult.allChanged(f(s)));
  void mutResult(DiffResult<S> Function(S) f);

  @override
  Cursor<S1> cast<S1>() => then(Lens<S, S1>.mkCast());

  @override
  S read(Reader r) {
    r.handleDispose(listen((_, __, ___) => r.onChanged()));
    return _value;
  }

  T atomically<T>(T Function(Cursor<S>) f);

  @override
  String toString() => 'Cursor($_value)';
}

class _ListenableState<T> {
  T _state;
  PathMapSet<void Function(T old, T nu, Diff diff)> _listenables = PathMapSet.empty();

  _ListenableState(this._state);

  T get bareState => _state;

  void Function() listen(Path path, void Function(T old, T nu, Diff diff) callback) {
    _listenables = _listenables.add(path, callback);
    return () {
      _listenables = _listenables.remove(path, callback);
    };
  }

  DiffResult<T> transformAndNotify(DiffResult<T> Function(T) transform) {
    final origState = _state;
    final result = transform(_state);
    _state = result.value;
    _listenables
        .connectedValues(result.diff.changed)
        .forEach((f) => f(origState, _state, result.diff));
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

  _CursorImpl(this.state, this.lens);

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens) {
    return _CursorImpl(state, this.lens.then(lens));
  }

  @override
  GetCursor<S2> thenGet<S2>(Getter<S, S2> getter) =>
      _CursorImpl(state, this.lens.then(Lens(getter.path, getter.get, (s, f) => s)));

  @override
  S get _value => lens.get(state.bareState);

  @override
  void mutResult(DiffResult<S> Function(S) f) {
    state.transformAndNotify((t) => lens.mutDiff(t, f));
  }

  @override
  V atomically<V>(V Function(Cursor<S> p1) f) {
    // TODO: implement
    return f(this);
  }

  @override
  void Function() listen(void Function(S old, S nu, Diff diff) f) {
    return state.listen(
      lens.path,
      (T old, T nu, Diff diff) => f(lens.get(old), lens.get(nu), diff.atPrefix(lens.path)),
    );
  }

  @override
  String toString() => 'Cursor($_value)';
}

abstract class CursorCallback {
  void onChanged() {}
  void onGet(WithDisposal<Path> result) => result.dispose();
  void onMut<S>(S old, S nu, Diff diff) {}
}

@immutable
class _GetCursorImpl<S> with GetCursor<S> {
  final S state;

  const _GetCursorImpl(this.state);

  @override
  S get _value => state;

  @override
  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter) => _GetCursorImpl(getter.get(state));

  @override
  void Function() listen(void Function(S old, S nu, Diff diff) f) {
    return () => null;
  }
}

extension CursorNullability<T> on Cursor<T?> {
  Cursor<T> get nonnull => then(Lens.identity<T?>().nonnull);
  Cursor<T> orElse(T defaultValue) => then(Lens(
        Path.empty(),
        (t) => t ?? defaultValue,
        (t, f) => f(t ?? defaultValue),
      ));
}

extension GetCursorNullability<T> on GetCursor<T?> {
  GetCursor<T> get nonnull => then(Lens.identity<T?>().nonnull);
  GetCursor<T> orElse(T defaultValue) => thenGet(Getter(Path.empty(), (t) => t ?? defaultValue));
}
