import 'package:ctx/ctx.dart';
import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

typedef PathMapSet<V> = TrieMapSet<Object, V>;

abstract class GetCursor<S> {
  const factory GetCursor(S state) = _ValueCursor<S>;
  factory GetCursor.compute(
    S Function(Ctx) computation, {
    required Ctx ctx,
    bool compare = false,
  }) =>
      StateCursor(_ComputedState(computation, ctx: ctx, compare: compare), Getter.identity());

  GetCursor<S1> then<S1>(Lens<S, S1> lens) => thenGet(lens);

  GetCursor<S1> thenGet<S1>(Getter<S, S1> getter);

  GetCursor<S1> thenOpt<S1>(
    OptLens<S, S1> lens, {
    String Function() errorMsg = _defaultThenOptErrorMsg,
  }) =>
      thenOptGet(lens, errorMsg: errorMsg);

  GetCursor<S1> thenOptGet<S1>(OptGetter<S, S1> getter, {String Function() errorMsg});

  void Function() listen(void Function(S old, S nu, Diff diff) f);

  S read(Ctx ctx);

  List<String> stringify();

  @override
  String toString() => stringify().join('\n');
}

extension GetCursorHelpers<S> on GetCursor<S> {
  Type type(Ctx ctx) => GetCursor.compute(
        (ctx) => this.read(ctx).runtimeType,
        ctx: ctx,
        compare: true,
      ).read(ctx);
}

abstract class Reader extends CtxElement {
  void onChanged();
  bool isListening(Object key);
  void handleDispose(Object key, void Function() dispose);
}

extension ReaderCtxExtension on Ctx {
  Ctx withReader(Reader reader) => withElement(reader);
  Reader? get reader => get<Reader>();
}

abstract class Cursor<S> implements GetCursor<S> {
  factory Cursor(S state) => MutableStateCursor(
        ListenableStateBase(state),
        Lens.identity(),
      );

  factory Cursor.compute(Cursor<S> Function(Ctx) computation, {required Ctx ctx}) =>
      GetCursor.compute(computation, ctx: ctx).flatten;

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens);

  @override
  Cursor<S1> thenOpt<S1>(OptLens<S, S1> getter, {String Function() errorMsg});

  void set(S s) => mut((_) => s);
  void mut(S Function(S) f) => mutResult((s) => DiffResult.allChanged(f(s)));
  void setResult(DiffResult<S> diff) => mutResult((_) => diff);
  void mutResult(DiffResult<S> Function(S) f);

  V atomically<V>(V Function(Cursor<S> p1) f) {
    // TODO: implement
    return f(this);
  }

  @override
  String toString() => stringify().join('\n');
}

extension GetCursorPartial<S> on GetCursor<S> {
  GetCursor<S1> cast<S1 extends S>() {
    if (this is GetCursor<S1>) return this as GetCursor<S1>;

    return thenOpt(
      OptLens(const Vec([]), (s) => s is S1 ? Optional(s) : Optional.none(), (s, f) => f(s as S1)),
      errorMsg: () => 'Tried to cast cursor of current type ${read(Ctx.empty).runtimeType} to $S1',
    );
  }
}

extension CursorPartial<S> on Cursor<S> {
  Cursor<S1> partial<S1>({
    required S1? Function(S) to,
    required DiffResult<S> Function(DiffResult<S1>) from,
    DiffResult<S1?> Function(S old, S nu, Diff)? update,
  }) =>
      MutableStateCursor(
        _MutablePartialViewState(viewed: this, to: to, from: from, update: update),
        Lens.identity(),
      );

  Cursor<S1> cast<S1 extends S>() {
    if (this is Cursor<S1>) return this as Cursor<S1>;

    return thenOpt(
      OptLens(const Vec([]), (s) => s is S1 ? Optional(s) : Optional.none(), (s, f) => f(s as S1)),
      errorMsg: () => 'Tried to cast cursor of current type ${read(Ctx.empty).runtimeType} to $S1',
    );
  }

  Cursor<S1> upcast<S1>() => thenOpt(
        OptLens(const Vec([]), (s) => s is S1 ? Optional(s) : Optional.none(),
            (s, f) => f(s as S1) as S),
        errorMsg: () =>
            'Tried to cast cursor of current type ${read(Ctx.empty).runtimeType} to $S1',
      );
}

abstract class ListenableState<T> {
  T get currentState;
  void Function() listen(Path path, void Function(T old, T nu, Diff diff) callback);
  List<String> stringify();
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
        .connectedValues(result.diff.allPaths())
        .forEach((f) => f(origState, _state, result.diff));
    return result;
  }

  @override
  List<String> stringify() {
    return ['ListenableStateBase<$T>'];
  }
}

String _defaultThenOptErrorMsg() => 'Tried to compose an optional cursor with no current value.';

abstract class StateCursorBase<T, S> implements GetCursor<S> {
  ListenableState<T> get state;
  OptGetter<T, S> get lens;

  @override
  GetCursor<S2> thenGet<S2>(Getter<S, S2> getter) => StateCursor(state, lens.then(getter));

  @override
  GetCursor<S2> thenOptGet<S2>(OptGetter<S, S2> getter,
      {String Function() errorMsg = _defaultThenOptErrorMsg}) {
    final newGetter = lens.then(getter);
    assert(newGetter.getOpt(state.currentState).isPresent, errorMsg());
    return StateCursor(state, newGetter);
  }

  @override
  S read(Ctx ctx) {
    final currentState = lens.getOpt(state.currentState);
    if (!(ctx.reader?.isListening(this) ?? true)) {
      ctx.reader?.handleDispose(
        this,
        state.listen(lens.path, (_, nu, ___) {
          if (lens.getOpt(nu).isPresent) ctx.reader!.onChanged();
        }),
      );
    }
    return currentState.unwrap!;
  }

  @override
  void Function() listen(void Function(S old, S nu, Diff diff) f) {
    return state.listen(
      lens.path,
      (T old, T nu, Diff diff) {
        lens
            .getOpt(nu)
            .ifPresent((nuS) => f(lens.getOpt(old).unwrap as S, nuS, diff.atPrefix(lens.path)));
      },
    );
  }

  @override
  bool operator ==(Object? other) {
    return other is StateCursorBase<T, S> && state == other.state && lens.path == other.lens.path;
  }

  @override
  int get hashCode => Object.hashAll([state, ...lens.path]);

  @override
  List<String> stringify() {
    final stateString = state.stringify();
    if (lens.path.isEmpty) {
      return [
        'StateCursor:${stateString.first}',
        ...stateString.skip(1),
      ];
    } else {
      return [
        'StateCursor:${[lens.path.join(" > ")]}:${stateString.first}',
        ...stateString.skip(1),
      ];
    }
  }
}

class StateCursor<T, S> with GetCursor<S>, StateCursorBase<T, S> {
  @override
  final ListenableState<T> state;
  @override
  final OptGetter<T, S> lens;

  StateCursor(this.state, this.lens);
}

@immutable
class MutableStateCursor<T, S> with Cursor<S>, StateCursorBase<T, S> {
  @override
  final MutableListenableState<T> state;
  @override
  final OptLens<T, S> lens;

  MutableStateCursor(this.state, this.lens);

  @override
  Cursor<S2> then<S2>(Lens<S, S2> lens) {
    return MutableStateCursor(state, this.lens.then(lens));
  }

  @override
  Cursor<S1> thenOpt<S1>(OptLens<S, S1> getter,
      {String Function() errorMsg = _defaultThenOptErrorMsg}) {
    final newLens = lens.then(getter);
    assert(newLens.getOpt(state.currentState).isPresent, errorMsg());
    return MutableStateCursor(state, newLens);
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
  GetCursor<S1> thenOptGet<S1>(OptGetter<S, S1> getter,
      {String Function() errorMsg = _defaultThenOptErrorMsg}) {
    final newState = getter.getOpt(state);
    assert(newState.isPresent, errorMsg());
    return _ValueCursor(newState.unwrap as S1);
  }

  @override
  void Function() listen(void Function(S old, S nu, Diff diff) f) {
    return () {};
  }

  @override
  S read(Ctx ctx) => state;

  @override
  List<String> stringify() {
    return ['ValueCursor($state)'];
  }
}

class _ComputedState<T> implements Reader, ListenableState<T> {
  final T Function(Ctx) computation;
  final Ctx ctx;
  final Map<Object, void Function()> disposals = {};
  final Set<Object> keepKeys = {};

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
  void Function() listen(Path path, void Function(T old, T nu, Diff diff) callback) =>
      _state.listen(path, callback);

  @override
  bool isListening(Object key) {
    keepKeys.add(key);
    return disposals.containsKey(key);
  }

  @override
  void handleDispose(Object key, void Function() dispose) => disposals[key] = dispose;

  @override
  void onChanged() {
    if (_state._listenables.isEmpty && dirty != true) {
      for (final dispose in disposals.values) {
        dispose();
      }
      disposals.clear();
      dirty = true;
      return;
    }

    final oldKeys = {...disposals.keys};

    final newState = computation(ctx.withReader(this));

    for (final removeKey in oldKeys.difference(keepKeys)) {
      disposals.remove(removeKey)!();
    }
    keepKeys.clear();

    if (compare && newState == _state.currentState) return;

    _state.transformAndNotify(
      (_) => DiffResult(newState, const Diff.allChanged()),
    );
  }

  @override
  List<String> stringify() {
    return ['ComputedState(current: $currentState)'];
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
        _state.transformAndNotify((_) => DiffResult(result.value as S, result.diff));
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
  List<String> stringify() {
    final viewedString = viewed.stringify();
    return [
      'View<$T as $S>(',
      '  ${currentState.runtimeType}',
      ...viewedString.map((s) => '  $s'),
      ')',
    ];
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
    _stateVar ??= ListenableStateBase(to(viewed.read(Ctx.empty)) as S);
    return _stateVar!;
  }

  @override
  DiffResult<S> transformAndNotify(DiffResult<S> Function(S p1) transform) {
    final result = transform(_state.currentState);
    viewed.setResult(from(result));
    return result;
  }
}

abstract class _FlattenStateBase<T> implements ListenableState<T> {
  GetCursor<GetCursor<T>> get viewed;
  void Function()? get disposeListener;
  set disposeListener(void Function()? disposeListener);

  ListenableStateBase<T> get _state;

  @override
  T get currentState => _state.currentState;

  @override
  void Function() listen(Path path, void Function(T old, T nu, Diff diff) callback) {
    final dispose = _state.listen(path, callback);

    if (disposeListener == null) {
      void listener(T old, T nu, Diff diff) =>
          _state.transformAndNotify((_) => DiffResult(nu, diff));

      var cursorDispose = viewed.read(Ctx.empty).listen(listener);
      final viewedDispose = viewed.listen((old, nu, diff) {
        cursorDispose();
        cursorDispose = nu.listen(listener);
        _state.transformAndNotify((_) => DiffResult(nu.read(Ctx.empty), Diff.allChanged()));
      });

      disposeListener = () {
        viewedDispose();
        cursorDispose();
      };
    }

    return () {
      dispose();
      if (_state._listenables.isEmpty) {
        if (disposeListener != null) disposeListener!();
        disposeListener = null;
      }
    };
  }

  @override
  List<String> stringify() {
    final viewedString = viewed.read(Ctx.empty).stringify();
    return [
      'Flatten<$T>(current:',
      '  ${currentState.runtimeType}',
      ...viewedString.map((s) => '  $s'),
      ')',
    ];
  }
}

class _FlattenState<T> with _FlattenStateBase<T> {
  @override
  final GetCursor<GetCursor<T>> viewed;
  @override
  void Function()? disposeListener;

  ListenableStateBase<T>? _stateVar;

  _FlattenState(this.viewed);

  @override
  ListenableStateBase<T> get _state {
    _stateVar ??= ListenableStateBase(viewed.read(Ctx.empty).read(Ctx.empty));
    return _stateVar!;
  }
}

class _MutableFlattenState<T> with _FlattenStateBase<T> implements MutableListenableState<T> {
  @override
  final GetCursor<Cursor<T>> viewed;
  @override
  void Function()? disposeListener;

  ListenableStateBase<T>? _stateVar;

  _MutableFlattenState(this.viewed);

  @override
  ListenableStateBase<T> get _state {
    _stateVar ??= ListenableStateBase(viewed.read(Ctx.empty).read(Ctx.empty));
    return _stateVar!;
  }

  @override
  DiffResult<T> transformAndNotify(DiffResult<T> Function(T p1) transform) {
    final result = transform(_state.currentState);
    viewed.read(Ctx.empty).setResult(result);
    return result;
  }
}

extension FlattenedGetCursorExtension<T> on GetCursor<GetCursor<T>> {
  GetCursor<T> get flatten => StateCursor(_FlattenState(this), Getter.identity());
}

extension FlattenedCursorExtension<T> on GetCursor<Cursor<T>> {
  Cursor<T> get flatten => MutableStateCursor(_MutableFlattenState(this), Lens.identity());
}
