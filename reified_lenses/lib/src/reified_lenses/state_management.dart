import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';
import 'reified_lenses.dart';

abstract class GetCursor<S> {
  const factory GetCursor(S state) = _ValueCursor;
  factory GetCursor.compute(S Function(Reader) reader) =>
      StateCursor(_ComputedState(reader), Getter.identity());

  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter);

  GetCursor<S1> then<S1>(Lens<S, S1> getter) => thenGet(getter);

  GetCursor<S1> cast<S1>() {
    assert(read(null) is S1);
    return thenGet(Getter<S, S1>.mkCast());
  }

  void Function() listen(void Function(S old, S nu, Diff diff) f);

  S read(Reader? r);

  @override
  String toString() => 'GetCursor(${read(null)})';
}

abstract class Reader {
  const factory Reader({
    required void Function() onChanged,
    required void Function(void Function()) handleDispose,
  }) = _CallbackReader;

  void onChanged();
  void handleDispose(void Function() dispose);
}

class _CallbackReader implements Reader {
  final void Function() _onChangedFn;
  final void Function(void Function()) _handleDisposeFn;

  const _CallbackReader({
    required void Function() onChanged,
    required void Function(void Function()) handleDispose,
  })  : _onChangedFn = onChanged,
        _handleDisposeFn = handleDispose;

  @override
  void onChanged() => _onChangedFn();

  @override
  void handleDispose(void Function() dispose) => _handleDisposeFn(dispose);
}

abstract class Cursor<S> implements GetCursor<S> {
  factory Cursor(S state) => MutableStateCursor(
        ListenableStateBase(state),
        Lens.identity(),
      );

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens);

  void set(S s) => mut((_) => s);
  void mut(S Function(S) f) => mutResult((s) => DiffResult.allChanged(f(s)));
  void mutResult(DiffResult<S> Function(S) f);

  @override
  Cursor<S1> cast<S1>() {
    assert(read(null) is S1);
    return then(Lens<S, S1>.mkCast());
  }

  V atomically<V>(V Function(Cursor<S> p1) f) {
    // TODO: implement
    return f(this);
  }

  @override
  String toString() => 'Cursor(${read(null)})';
}

extension CursorPartial<S> on Cursor<S> {
  Cursor<S1> partial<S1>(
          {required S1? Function(S) to,
          required DiffResult<S> Function(DiffResult<S1>) from,
          DiffResult<S1?> Function(S old, S nu, Diff)? update}) =>
      MutableStateCursor(
        _PartialViewState(viewed: this, to: to, from: from, update: update),
        Lens.identity(),
      );
}

abstract class ListenableState<T> {
  T get currentState;
  void Function() listen(Path path, void Function(T old, T nu, Diff diff) callback);
}

abstract class MutableListenableState<T> implements ListenableState<T> {
  DiffResult<T> transformAndNotify(DiffResult<T> Function(T) transform);
}

class ListenableStateBase<T> implements MutableListenableState<T> {
  T _state;
  PathMapSet<void Function(T old, T nu, Diff diff)> _listenables = PathMapSet.empty();

  ListenableStateBase(this._state);

  @override
  T get currentState => _state;

  @override
  void Function() listen(Path path, void Function(T old, T nu, Diff diff) callback) {
    _listenables = _listenables.add(path, callback);
    return () {
      _listenables = _listenables.remove(path, callback);
    };
  }

  @override
  DiffResult<T> transformAndNotify(DiffResult<T> Function(T) transform) {
    final origState = _state;
    final result = transform(_state);
    _state = result.value;
    _listenables
        .connectedValues(result.diff.changed.union(result.diff.added).union(result.diff.removed))
        .forEach((f) => f(origState, _state, result.diff));
    return result;
  }
}

abstract class StateCursorBase<T, S> implements GetCursor<S> {
  ListenableState<T> get state;
  Getter<T, S> get lens;

  @override
  GetCursor<S2> thenGet<S2>(Getter<S, S2> getter) => StateCursor(
        state,
        this.lens.thenGet(Getter(getter.path, getter.get)),
      );

  @override
  S read(Reader? r) {
    r?.handleDispose(listen((_, __, ___) => r.onChanged()));
    return lens.get(state.currentState);
  }

  @override
  void Function() listen(void Function(S old, S nu, Diff diff) f) {
    return state.listen(
      lens.path,
      (T old, T nu, Diff diff) => f(lens.get(old), lens.get(nu), diff.atPrefix(lens.path)),
    );
  }

  @override
  bool operator ==(Object? other) {
    return other is StateCursorBase<T, S> && state == other.state && lens.path == other.lens.path;
  }

  @override
  int get hashCode => Object.hashAll([state, ...lens.path]);
}

class StateCursor<T, S> with GetCursor<S>, StateCursorBase<T, S> {
  @override
  final ListenableState<T> state;
  @override
  final Getter<T, S> lens;

  StateCursor(this.state, this.lens);
}

@immutable
class MutableStateCursor<T, S> with Cursor<S>, StateCursorBase<T, S> {
  @override
  final MutableListenableState<T> state;
  @override
  final Lens<T, S> lens;

  MutableStateCursor(this.state, this.lens);

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens) {
    return MutableStateCursor(state, this.lens.then(lens));
  }

  @override
  void mutResult(DiffResult<S> Function(S) f) {
    state.transformAndNotify((t) => lens.mutDiff(t, f));
  }
}

@immutable
class _ValueCursor<S> with GetCursor<S> {
  final S state;

  const _ValueCursor(this.state);

  @override
  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter) => _ValueCursor(getter.get(state));

  @override
  void Function() listen(void Function(S old, S nu, Diff diff) f) {
    return () {};
  }

  @override
  S read(Reader? r) => state;
}

extension CursorOptional<T> on Cursor<Optional<T>> {
  Cursor<T> get whenPresent => partial(
        to: (t) => t.unwrap,
        from: (diff) => DiffResult(Optional(diff.value), diff.diff),
        update: (old, nu, diff) => DiffResult(nu.unwrap, diff),
      );

  Cursor<T> orElse(T defaultValue) => then(Lens(
        Path.empty(),
        (t) => t.orElse(defaultValue),
        (t, f) => Optional(f(t.orElse(defaultValue))),
      ));
}

class _ComputedState<T> implements Reader, ListenableState<T> {
  final T Function(Reader) computation;
  final List<void Function()> disposals = [];

  ListenableStateBase<T>? _stateVar;
  ListenableStateBase<T> get _state {
    _stateVar ??= ListenableStateBase(computation(this));
    return _stateVar!;
  }

  bool dirty = false;

  @override
  T get currentState {
    if (dirty) {
      _state.transformAndNotify(
        (_) => DiffResult(computation(this), const Diff.allChanged()),
      );
      dirty = false;
    }
    return _state.currentState;
  }

  _ComputedState(this.computation);

  @override
  void Function() listen(Path path, void Function(T old, T nu, Diff diff) callback) {
    final dispose = _state.listen(path, callback);
    return () {
      dispose();
      if (_state._listenables.isEmpty) {
        for (final f in disposals) {
          f();
        }
        disposals.clear();
        dirty = true;
      }
    };
  }

  @override
  void handleDispose(void Function() dispose) {
    disposals.add(dispose);
  }

  @override
  void onChanged() {
    for (final f in disposals) {
      f();
    }
    disposals.clear();
    _state.transformAndNotify(
      (_) => DiffResult(computation(this), const Diff.allChanged()),
    );
  }
}

class _PartialViewState<T, S> implements MutableListenableState<S> {
  final Cursor<T> viewed;
  final S? Function(T) to;
  final DiffResult<T> Function(DiffResult<S>) from;
  final DiffResult<S?> Function(T old, T nu, Diff)? update;
  void Function()? disposeListener;

  ListenableStateBase<S>? _stateVar;

  _PartialViewState({
    required this.viewed,
    required this.to,
    required this.from,
    this.update,
  });

  ListenableStateBase<S> get _state {
    _stateVar ??= ListenableStateBase(to(viewed.read(null))!);
    return _stateVar!;
  }

  @override
  S get currentState => _state.currentState;

  @override
  void Function() listen(Path path, void Function(S old, S nu, Diff diff) callback) {
    final dispose = _state.listen(path, callback);

    disposeListener ??= viewed.listen((old, nu, diff) {
      late final DiffResult<S?> result;

      if (update != null) {
        result = update!(old, nu, diff);
      } else {
        result = DiffResult(to(nu), const Diff.allChanged());
      }

      if (result.value != null) {
        _state.transformAndNotify((_) => DiffResult(result.value!, result.diff));
      }
    });

    return () {
      dispose();
      if (_state._listenables.isEmpty) {
        if (disposeListener != null) disposeListener!();
        disposeListener = null;
      }
    };
  }

  @override
  DiffResult<S> transformAndNotify(DiffResult<S> Function(S p1) transform) {
    final result = transform(_state.currentState);
    viewed.mutResult((_) => from(result));
    return result;
  }
}
