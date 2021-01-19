import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

@immutable
class GetResult<A> {
  final A value;
  final Iterable<Object> path;

  const GetResult(this.value, this.path);
}

@immutable
class MutResult<A> {
  final A value;
  final Iterable<Object> path;
  final TrieMap<Object, bool> mutated;

  const MutResult(this.value, this.path, [TrieMap<Object, bool>? mutated])
      : mutated = mutated ?? const TrieMap.empty();

  const MutResult.unchanged(this.value)
      : path = const Iterable.empty(),
        mutated = const TrieMap.empty();

  const MutResult.allChanged(this.value)
      : path = const Iterable.empty(),
        mutated = const TrieMap({true}, {});

  MutResult.path(this.value, this.path)
      : mutated = TrieMap<Object, bool>.empty().add(path, true);
}

typedef GetterF<T, S> = S Function(T);

typedef ReifiedGetterF<T, S> = GetResult<S> Function(T);

typedef MutaterF<T, S> = T Function(T, S Function(S));

typedef ReifiedMutaterF<T, S> = MutResult<T> Function(T, S Function(S));

typedef SetterF<T, S> = T Function(T, S);

typedef ReifiedSetterF<T, S> = MutResult<T> Function(T, S);

typedef TransformF<T> = T Function(T);

typedef ReifiedTransformF<T> = MutResult<T> Function(T);

GetResult<T> _identityGetter<T>(T t) => GetResult(t, Iterable.empty());
MutResult<T> _identityMutater<T>(T t, T Function(T) f) =>
    MutResult.path(f(t), Iterable.empty());

abstract class ThenLens<S1> {
  @protected
  ThenLens<S2> then<S2>(Lens<S1, S2> lens);
}

mixin ThenGet<S1> implements ThenLens<S1> {
  @protected
  ThenGet<S2> thenGet<S2>(Getter<S1, S2> getter);
}

//////////////////////////////////////////////////////////
mixin ThenMut<S1> implements ThenLens<S1> {
  @protected
  ThenMut<S2> thenMut<S2>(Mutater<S1, S2> mutater);
}

//////////////////////////////////////////////////////////
mixin Getter<T, S> implements ThenGet<S>, ThenLens<S> {
  static Getter<T, S> mkCast<T, S>() =>
      _GetterImpl((T t) => GetResult(t as S, Iterable.empty()));
  static Getter<T, S> mk<T, S>(ReifiedGetterF<T, S> getF) => _GetterImpl(getF);
  static Getter<T, T> identity<T>() => _GetterImpl(_identityGetter);
  static Getter<T, S> field<T, S>(Object field, GetterF<T, S> getter) =>
      Getter.mk((t) => GetResult(getter(t), [field]));

  GetResult<S> getResult(T t);

  S get(T t) => getResult(t).value;

  @override
  Getter<T, S2> thenGet<S2>(Getter<S, S2> getter) {
    return Getter.mk((t) {
      final sResult = getResult(t);
      final s1Result = getter.getResult(sResult.value);
      return GetResult(s1Result.value, sResult.path + s1Result.path);
    });
  }

  @override
  Getter<T, S2> then<S2>(Lens<S, S2> getter);

  Getter<T, S2> cast<S2>() => thenGet(Getter.mkCast<S, S2>());
}

extension GetterNullability<T, S> on Getter<T, S?> {
  Getter<T, S> get nonnull => thenGet(Getter.mk(
        (s) => GetResult(s!, Iterable.empty()),
      ));
}

@immutable
class _GetterImpl<T, S> with Getter<T, S> {
  final ReifiedGetterF<T, S> _getter;

  _GetterImpl(this._getter);

  @override
  GetResult<S> getResult(T t) => _getter(t);

  @override
  Getter<T, S2> then<S2>(Lens<S, S2> lens) => thenGet(lens);
}

//////////////////////////////////////////////////////////
abstract class Mutater<T, S> implements ThenMut<S>, ThenLens<S> {
  static Mutater<T, S> mkCast<T, S>() => _MutaterImpl(
      (T t, S Function(S) f) => MutResult(f(t as S) as T, Iterable.empty()));

  static Mutater<T, S> mk<T, S>(ReifiedMutaterF<T, S> mutater) =>
      _MutaterImpl(mutater);

  static Mutater<T, T> identity<T>() => _MutaterImpl(_identityMutater);

  static Mutater<T, S> field<T, S>(Object field, MutaterF<T, S> mutater) =>
      _MutaterImpl((t, f) => MutResult.path(
            mutater(t, f),
            [field],
          ));

  MutResult<T> mutResult(T t, S Function(S s) f);

  Mutater<T0, S> mutAfter<T0>(Mutater<T0, T> prevMutater) {
    return Mutater.mk((t0, f) {
      MutResult<T>? tResult;
      final t0Result = prevMutater.mutResult(t0, (t) {
        tResult = mutResult(t, f);
        return tResult!.value;
      });
      return MutResult(
        t0Result.value,
        t0Result.path + tResult!.path,
        // TODO: figure out this logic
        tResult!.mutated.prepend(t0Result.path),
      );
    });
  }

  @override
  Mutater<T, S2> thenMut<S2>(Mutater<S, S2> mutater) => mutater.mutAfter(this);

  @override
  Mutater<T, S2> then<S2>(Lens<S, S2> lens);

  T mut(T t, S Function(S) f) => mutResult(t, f).value;

  MutResult<T> setResult(T t, S value) => mutResult(t, (_) => value);

  T set(T t, S value) => setResult(t, value).value;

  ReifiedSetterF<T, S> get setter => (t, s) => setResult(t, s);

  ReifiedTransformF<T> transform(S Function(S) f) => (t) => mutResult(t, f);
  ReifiedTransformF<T> reifiedTransform(ReifiedTransformF<S> f) {
    return (t) {
      MutResult<S>? sResult;
      final tResult = mutResult(t, (s) {
        sResult = f(s);
        return sResult!.value;
      });
      return MutResult(
        tResult.value,
        tResult.path + sResult!.path,
        // TODO: figure out this logic
        sResult!.mutated.prepend(tResult.path),
      );
    };
  }

  Mutater<T, S2> cast<S2>() => thenMut(Mutater.mkCast<S, S2>());
}

extension MutaterNullability<T, S> on Mutater<T, S?> {
  Mutater<T, S> get nonnull => thenMut(Mutater.mk((s, f) =>
      MutResult(f(s!), const Iterable.empty(), const TrieMap.empty())));
}

@immutable
class _MutaterImpl<T, S> with Mutater<T, S> {
  final ReifiedMutaterF<T, S> _mutater;

  _MutaterImpl(this._mutater);

  @override
  MutResult<T> mutResult(T t, S Function(S s) f) => _mutater(t, f);

  @override
  Mutater<T, S2> then<S2>(Lens<S, S2> lens) => thenMut(lens);
}

extension SetterExt<T, S> on ReifiedSetterF<T, S> {
  T set(T t, S value) => this(t, value).value;
  ReifiedTransformF<T> transform(S value) => (t) => this(t, value);
}

//////////////////////////////////////////////////////////
abstract class Lens<T, S> with Mutater<T, S> implements Getter<T, S> {
  static Lens<T, S> mkCast<T, S>() => _LensImpl(
        Getter.mkCast<T, S>().getResult,
        Mutater.mkCast<T, S>().mutResult,
      );

  static Lens<T, S> mk<T, S>(
    ReifiedGetterF<T, S> getF,
    ReifiedMutaterF<T, S> mutF,
  ) =>
      _LensImpl(getF, mutF);

  static Lens<T, T> identity<T>() =>
      _LensImpl<T, T>(_identityGetter, _identityMutater);

  static Lens<T, S> field<T, S>(
    Object field,
    S Function(T t) getter,
    T Function(T t, S Function(S s) s) mutater,
  ) =>
      _LensImpl(
        Getter.field(field, getter).getResult,
        Mutater.field(field, mutater).mutResult,
      );

  @override
  Lens<T, S2> then<S2>(Lens<S, S2> lens);

  @override
  Lens<T, S2> cast<S2>() => then(Lens.mkCast<S, S2>());
}

extension LensNullability<T, S> on Lens<T, S?> {
  Lens<T, S> get nonnull => then(Lens.mk(
        (s) => GetResult(s!, const Iterable.empty()),
        (s, f) =>
            MutResult(f(s!), const Iterable.empty(), const TrieMap.empty()),
      ));
}

@immutable
class _LensImpl<T, S> extends Lens<T, S> {
  final ReifiedGetterF<T, S> _getF;
  final ReifiedMutaterF<T, S> _mutF;

  _LensImpl(this._getF, this._mutF);

  @override
  GetResult<S> getResult(T t) => _getF(t);

  @override
  MutResult<T> mutResult(T t, S Function(S s) f) => _mutF(t, f);

  @override
  Lens<T, S2> then<S2>(Lens<S, S2> lens) {
    return Lens.mk(thenGet(lens).getResult, thenMut(lens).mutResult);
  }

  @override
  S get(T t) => getResult(t).value;

  @override
  Getter<T, S2> thenGet<S2>(Getter<S, S2> getter) =>
      Getter.mk(_getF).thenGet(getter);
}

//////////////////////////////////////////////////////////
class Traversal<O, T, S, S1> with Mutater<T, S1> {
  final Mutater<T, O> _prefix;
  final Mutater<S, S1> _suffix;
  final Iterable<GetResult<S>> Function(O) _to;
  final O Function(Iterable<S>) _from;

  Traversal._(this._to, this._from, this._prefix, this._suffix);
  static Traversal<O, O, S, S> mk<O, S>(
    Iterable<GetResult<S>> Function(O) to,
    O Function(Iterable<S>) from,
  ) =>
      Traversal._(to, from, Mutater.identity(), Mutater.identity());

  @override
  Traversal<O, T, S, S2> then<S2>(Lens<S1, S2> lens) {
    return thenMut(lens);
  }

  @override
  Traversal<O, T, S, S2> thenMut<S2>(Mutater<S1, S2> mutater) {
    return Traversal._(_to, _from, _prefix, _suffix.thenMut(mutater));
  }

  @override
  MutResult<T> mutResult(T t, S1 Function(S1 s) f) {
    var sMutateds = TrieMap<Object, bool>.empty();
    final tResult = _prefix.mutResult(t, (o) {
      final resultO = _from(_to(o).map((s) {
        final sResult = _suffix.mutResult(s.value, f);
        sMutateds = sResult.mutated.prepend(s.path);
        return sResult.value;
      }));
      return resultO;
    });
    return MutResult(
      tResult.value,
      tResult.path,
      tResult.mutated.merge(sMutateds.prepend(tResult.path)),
    );
  }

  @override
  Traversal<O, T0, S, S1> mutAfter<T0>(Mutater<T0, T> arg) {
    return Traversal._(_to, _from, _prefix.mutAfter(arg), _suffix);
  }
}

extension _IterableAppend<V> on Iterable<V> {
  Iterable<V> operator +(Iterable<V> other) => this.followedBy(other);
}
