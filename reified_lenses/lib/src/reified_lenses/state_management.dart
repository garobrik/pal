import 'package:ctx/ctx.dart';
import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';
import 'reified_lenses.dart';

abstract class GetCursor<S> {
  const factory GetCursor(S state) = _ValueCursor;
  factory GetCursor.compute(S Function(Ctx) computation,
          {required Ctx ctx, bool compare = false}) =>
      StateCursor(_ComputedState(computation, ctx: ctx, compare: compare), Getter.identity());

  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter);

  GetCursor<S1> then<S1>(Lens<S, S1> getter) => thenGet(getter);

  void Function() listen(void Function(S old, S nu, Diff diff) f);

  S read(Ctx ctx);

  @override
  String toString() => 'GetCursor(${read(Ctx.empty)})';
}

extension GetCursorHelpers<S> on GetCursor<S> {
  Type type(Ctx ctx) => GetCursor.compute(
        (ctx) => this.read(ctx).runtimeType,
        ctx: ctx,
        compare: true,
      ).read(ctx);
}

abstract class Reader extends CtxElement {
  const factory Reader({
    required void Function() onChanged,
    required void Function(void Function()) handleDispose,
  }) = _CallbackReader;

  void onChanged();
  void handleDispose(void Function() dispose);
}

extension ReaderCtxExtension on Ctx {
  Ctx withReader(Reader reader) => withElement(reader);
  Reader? get reader => get<Reader>();
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
  void setResult(DiffResult<S> diff) => mutResult((_) => diff);
  void mutResult(DiffResult<S> Function(S) f);

  V atomically<V>(V Function(Cursor<S> p1) f) {
    // TODO: implement
    return f(this);
  }

  @override
  String toString() => 'Cursor(${read(Ctx.empty)})';
}

extension GetCursorPartial<S> on GetCursor<S> {
  GetCursor<S1> partial<S1>(
          {required S1? Function(S) to, DiffResult<S1?> Function(S old, S nu, Diff)? update}) =>
      StateCursor(
        _PartialViewState(viewed: this, to: to, update: update),
        Getter.identity(),
      );

  GetCursor<S1> cast<S1 extends S>() {
    assert(
      this.read(Ctx.empty) is S1,
      'Tried to cast cursor of current type ${this.type(Ctx.empty)} to $S1',
    );
    return partial(
      to: (s) => s is S1 ? s : null,
      update: (_, nu, diff) => DiffResult(nu is S1 ? nu : null, diff),
    );
  }
}

extension OptionalCast<S> on Cursor<Optional<S>> {
  Cursor<Optional<S1>> optionalCast<S1 extends S>() {
    assert(
      this.read(Ctx.empty).unwrap is S1?,
      'Tried to cast cursor of current type ${this.type(Ctx.empty)} to $S1',
    );
    return partial(
      to: (s) => s.unwrap is S1? ? Optional.fromNullable(s.unwrap as S1?) : null,
      from: (s1) => s1,
      update: (_, nu, diff) =>
          DiffResult(nu.unwrap is S1? ? Optional.fromNullable(nu.unwrap as S1?) : null, diff),
    );
  }
}

extension CursorPartial<S> on Cursor<S> {
  Cursor<S1> partial<S1>(
          {required S1? Function(S) to,
          required DiffResult<S> Function(DiffResult<S1>) from,
          DiffResult<S1?> Function(S old, S nu, Diff)? update}) =>
      MutableStateCursor(
        _MutablePartialViewState(viewed: this, to: to, from: from, update: update),
        Lens.identity(),
      );

  Cursor<S1> cast<S1 extends S>() {
    assert(
      this.read(Ctx.empty) is S1,
      'Tried to cast cursor of current type ${this.type(Ctx.empty)} to $S1',
    );
    return partial(
      to: (s) => s is S1 ? s : null,
      from: (s1) => s1,
      update: (_, nu, diff) => DiffResult(nu is S1 ? nu : null, diff),
    );
  }
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

  @override
  String toString() {
    return 'ListenableStatebase<$T>';
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
  S read(Ctx ctx) {
    final currentState = lens.get(state.currentState);
    ctx.reader?.handleDispose(listen((_, __, ___) => ctx.reader!.onChanged()));
    return currentState;
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

class CallbackStateCursor<T, S> with Cursor<S>, StateCursorBase<T, S> {
  @override
  final ListenableState<T> state;
  @override
  final Lens<T, S> lens;
  final void Function(DiffResult<T> diff) callback;

  CallbackStateCursor(this.state, this.lens, this.callback);

  @override
  void mutResult(DiffResult<S> Function(S p1) f) {
    callback(lens.mutDiff(state.currentState, f));
  }

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens) {
    return CallbackStateCursor(state, this.lens.then(lens), callback);
  }
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

  @override
  String toString() {
    return 'MutableStateCursor(${this.read(Ctx.empty)}, ${lens.path}, $state)';
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
  S read(Ctx ctx) => state;
}

extension CursorOptional<T> on Cursor<Optional<T>> {
  Cursor<T> get whenPresent {
    assert(this.read(Ctx.empty).unwrap != null);
    return partial(
      to: (t) => t.unwrap,
      from: (diff) => DiffResult(Optional(diff.value), diff.diff),
      update: (old, nu, diff) => DiffResult(nu.unwrap, diff),
    );
  }

  Cursor<T> orElse(T defaultValue) => then(Lens(
        Path.empty(),
        (t) => t.orElse(defaultValue),
        (t, f) => Optional(f(t.orElse(defaultValue))),
      ));
}

class _ComputedState<T> implements Reader, ListenableState<T> {
  final T Function(Ctx) computation;
  final Ctx ctx;
  final List<void Function()> disposals = [];

  ListenableStateBase<T>? _stateVar;
  ListenableStateBase<T> get _state {
    _stateVar ??= ListenableStateBase(computation(ctx.withReader(this)));
    return _stateVar!;
  }

  bool dirty = false;
  final bool compare;

  @override
  T get currentState {
    if (dirty) {
      onChanged();
      dirty = false;
    }
    return _state.currentState;
  }

  _ComputedState(this.computation, {required this.ctx, this.compare = false});

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

    final newState = computation(ctx.withReader(this));
    late final Diff diff;
    if (compare && newState == _state.currentState) {
      diff = const Diff();
    } else {
      diff = const Diff.allChanged();
    }

    _state.transformAndNotify(
      (_) => DiffResult(newState, diff),
    );
  }
}

abstract class _PartialViewStateBase<T, S> implements ListenableState<S> {
  GetCursor<T> get viewed;
  S? Function(T) get to;
  DiffResult<S?> Function(T old, T nu, Diff)? get update;
  void Function()? get disposeListener;
  set disposeListener(void Function()? disposeListener);

  ListenableStateBase<S> get _state;

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
}

class _PartialViewState<T, S> with _PartialViewStateBase<T, S> {
  @override
  final GetCursor<T> viewed;
  @override
  final S? Function(T) to;
  @override
  final DiffResult<S?> Function(T old, T nu, Diff)? update;
  @override
  void Function()? disposeListener;

  ListenableStateBase<S>? _stateVar;

  _PartialViewState({
    required this.viewed,
    required this.to,
    this.update,
  });

  @override
  ListenableStateBase<S> get _state {
    _stateVar ??= ListenableStateBase(to(viewed.read(Ctx.empty))!);
    return _stateVar!;
  }
}

class _MutablePartialViewState<T, S>
    with _PartialViewStateBase<T, S>
    implements MutableListenableState<S> {
  @override
  final Cursor<T> viewed;
  @override
  final S? Function(T) to;
  final DiffResult<T> Function(DiffResult<S>) from;
  @override
  final DiffResult<S?> Function(T old, T nu, Diff)? update;
  @override
  void Function()? disposeListener;

  ListenableStateBase<S>? _stateVar;

  _MutablePartialViewState({
    required this.viewed,
    required this.to,
    required this.from,
    this.update,
  });

  @override
  ListenableStateBase<S> get _state {
    _stateVar ??= ListenableStateBase(to(viewed.read(Ctx.empty))!);
    return _stateVar!;
  }

  @override
  DiffResult<S> transformAndNotify(DiffResult<S> Function(S p1) transform) {
    final result = transform(_state.currentState);
    viewed.setResult(from(result));
    return result;
  }

  @override
  String toString() {
    return 'MutablePartialViewState<$S>($viewed)';
  }
}
