import 'package:meta/meta.dart';
import 'zoom.dart';
import 'path.dart';

@immutable
class GetResult<A> {
  final A value;
  final Path<Object> path;

  const GetResult(this.value, this.path);
}

@immutable
class MutResult<A> {
  final A value;
  final Path<Object> path;
  final Set<Path<Object>> mutated;

  MutResult(this.value, this.path, [Set<Path<Object>> mutated])
      : this.mutated = mutated ?? Set.identity();

  MutResult.path(this.value, this.path) : this.mutated = Set.of([path]);
}

typedef IdF<T> = T Function(T);
typedef GetterF<T, S> = GetResult<S> Function(T);
typedef MutaterF<T, S> = MutResult<T> Function(T, S Function(S));
typedef SetterF<T, S> = MutResult<T> Function(T, S);
typedef TransformF<T> = MutResult<T> Function(T);
GetResult<T> _identityGetter<T>(T t) => GetResult(t, Path());
MutResult<T> _identityMutater<T>(T t, T Function(T) f) =>
    MutResult.path(f(t), Path());

//////////////////////////////////////////////////////////
abstract class ThenLensInterface<C extends ThenLens, S1>
implements Zoom<C, S1> {
  @protected
  Zoom<C, S2> then<S2>(Zoom<Lens<S1>, S2> lens);
}

abstract class ThenLens {}

extension ThenLensInterfaceExtension<C extends ThenLens, S1> on Zoom<C, S1> {
  ThenLensInterface<C, S1> get _this => this as ThenLensInterface<C, S1>;

  Zoom<C, S2> then<S2>(Zoom<Lens<S1>, S2> lens) => _this.then(lens);
}

//////////////////////////////////////////////////////////
mixin ThenGetInterface<C1 extends ThenGet<C2>, C2, S1> implements Zoom<C1, S1> {
  @protected
  Zoom<C2, S2> thenGet<S2>(Zoom<Getter<S1>, S2> getter);
}

mixin ThenGet<C2> {}

extension ThenGetInterfaceExtension<C2, S1> on Zoom<ThenGet<C2>, S1> {
  ThenGetInterface<ThenGet<C2>, C2, S1> get _this =>
      this as ThenGetInterface<ThenGet<C2>, C2, S1>;

  Zoom<C2, S2> thenGet<S2>(Zoom<Getter<S1>, S2> getter) =>
      _this.thenGet(getter);
}

//////////////////////////////////////////////////////////
mixin ThenMutInterface<C1 extends ThenMut<C2>, C2, S1> implements Zoom<C1, S1> {
  @protected
  Zoom<C2, S2> thenMut<S2>(Zoom<Mutater<S1>, S2> mutater);
}

mixin ThenMut<C2> {}

extension ThenMutInterfaceExtension<C2, S1> on Zoom<ThenMut<C2>, S1> {
  ThenMutInterface<ThenMut<C2>, C2, S1> get _this =>
      this as ThenMutInterface<ThenMut<C2>, C2, S1>;

  Zoom<C2, S2> thenMut<S2>(Zoom<Mutater<S1>, S2> mutater) =>
      _this.thenMut(mutater);
}

//////////////////////////////////////////////////////////
mixin GetterInterface<C extends Getter<T>, T, S>
    implements ThenGetInterface<C, Getter<T>, S>, ThenLensInterface<C, S> {
  @protected
  GetResult<S> getResult(T t);

  @override
  Zoom<Getter<T>, S2> thenGet<S2>(Zoom<Getter<S>, S2> getter) {
    return Getter.mk((t) {
      final sResult = this.getResult(t);
      final s1Result = getter.getResult(sResult.value);
      return GetResult(s1Result.value, sResult.path + s1Result.path);
    });
  }
}

abstract class Getter<T> implements ThenGet<Getter<T>>, ThenLens {
  static Zoom<Getter<T>, S> mk<T, S>(GetterF<T, S> getF) => _GetterImpl(getF);
  static const _identity = _GetterImpl<dynamic, dynamic>(_identityGetter);
  static Zoom<Getter<T>, T> identity<T>() => _identity as _GetterImpl<T, T>;
}

@immutable
class _GetterImpl<T, S> with GetterInterface<Getter<T>, T, S> {
  final GetterF<T, S> _getter;

  const _GetterImpl(this._getter);

  @override
  GetResult<S> getResult(T t) => _getter(t);

  @override
  Zoom<Getter<T>, S2> then<S2>(Zoom<Lens<S>, S2> lens) => this.thenGet(lens);
}

extension GetterInterfaceExtension<T, S> on Zoom<Getter<T>, S> {
  GetterInterface<Getter<T>, T, S> get _this =>
      this as GetterInterface<Getter<T>, T, S>;

  GetResult<S> getResult(T t) => _this.getResult(t);

  S get(T t) => _this.getResult(t).value;
}

//////////////////////////////////////////////////////////
abstract class MutaterInterface<C extends Mutater<T>, T, S>
    implements ThenMutInterface<C, Mutater<T>, S>, ThenLensInterface<C, S> {
  @protected
  MutResult<T> mutResult(T t, S f(S s));

  @protected
  Zoom<Mutater<T0>, S> mutAfter<T0>(Zoom<Mutater<T0>, T> prevMutater) {
    return Mutater.mk((t0, f) {
      MutResult<T> tResult;
      final t0Result = prevMutater.mutResult(t0, (t) {
        tResult = this.mutResult(t, f);
        return tResult.value;
      });
      return MutResult(
        t0Result.value,
        t0Result.path + tResult.path,
        t0Result.mutated
            .union(Set.of(tResult.mutated.map((path) => t0Result.path + path))),
      );
    });
  }

  @override
  Zoom<Mutater<T>, S2> thenMut<S2>(Zoom<Mutater<S>, S2> mutater) =>
      mutater.mutAfter(this);
}

abstract class Mutater<T> implements ThenMut<Mutater<T>>, ThenLens {
  static Zoom<Mutater<T>, S> mk<T, S>(MutaterF<T, S> mutater) =>
      _MutaterImpl(mutater);

  static const _identity = _MutaterImpl<dynamic, dynamic>(_identityMutater);
  static Zoom<Mutater<T>, T> identity<T>() => _identity as _MutaterImpl<T, T>;
}

@immutable
class _MutaterImpl<T, S> with MutaterInterface<Mutater<T>, T, S> {
  final MutaterF<T, S> _mutater;

  const _MutaterImpl(this._mutater);

  @override
  MutResult<T> mutResult(T t, S Function(S s) f) => _mutater(t, f);

  @override
  Zoom<Mutater<T>, S2> then<S2>(Zoom<Lens<S>, S2> lens) => this.thenMut(lens);
}

extension MutaterInterfaceExtension<T, S> on Zoom<Mutater<T>, S> {
  MutaterInterface<Mutater<T>, T, S> get _this =>
      this as MutaterInterface<Mutater<T>, T, S>;

  MutResult<T> mutResult(T t, S Function(S) f) => _this.mutResult(t, f);

  Zoom<Mutater<T0>, S> mutAfter<T0>(Zoom<Mutater<T0>, T> prevMutater) =>
      _this.mutAfter(prevMutater);

  T mut(T t, S Function(S) f) => _this.mutResult(t, f).value;

  MutResult<T> setResult(T t, S value) => _this.mutResult(t, (_) => value);

  T set(T t, S value) => _this.setResult(t, value).value;

  SetterF<T, S> get setter => (t, s) => _this.setResult(t, s);

  TransformF<T> transform(S Function(S) f) => (t) => _this.mutResult(t, f);
}

extension SetterExt<T, S> on SetterF<T, S> {
  T set(T t, S value) => this(t, value).value;
  TransformF<T> mut(S value) => (t) => this(t, value);
}

//////////////////////////////////////////////////////////
abstract class LensInterface<C extends Lens<T>, T, S>
    with MutaterInterface<C, T, S>, GetterInterface<C, T, S> {
  const LensInterface();
}

@immutable
class _LensImpl<T, S> extends LensInterface<Lens<T>, T, S> {
  final GetterF<T, S> _getF;
  final MutaterF<T, S> _mutF;

  const _LensImpl(this._getF, this._mutF);

  @override
  GetResult<S> getResult(T t) => _getF(t);

  @override
  MutResult<T> mutResult(T t, S f(S s)) => _mutF(t, f);

  @override
  Zoom<Lens<T>, S2> then<S2>(Zoom<Lens<S>, S2> lens) {
    return Lens.mk(this.thenGet(lens).getResult, this.thenMut(lens).mutResult);
  }
}

abstract class Lens<T> implements Getter<T>, Mutater<T> {
  static Zoom<Lens<T>, S> mk<T, S>(GetterF<T, S> getF, MutaterF<T, S> mutF) =>
      _LensImpl(getF, mutF);

  static const _identity =
      _LensImpl<dynamic, dynamic>(_identityGetter, _identityMutater);
  static Zoom<Lens<T>, T> identity<T>() => _identity as _LensImpl<T, T>;

  static Zoom<Lens<T>, S> field<T, S>(String fdName, S Function(T t) getter,
          T Function(T t, S Function(S s) s) mutater) =>
      _LensImpl(
        (t) => GetResult(getter(t), Path(fdName)),
        (t, s) =>
            MutResult(mutater(t, s), Path(fdName), Set.of([Path(fdName)])),
      );
}

//////////////////////////////////////////////////////////
class TraversalInterface<C extends Traversal<O, T, S>, O, T, S, S1>
    implements
        ThenMutInterface<C, Mutater<T>, S1>,
        ThenLensInterface<C, S1>,
        MutaterInterface<C, T, S1> {
  final Zoom<Mutater<T>, O> _prefix;
  final Zoom<Mutater<S>, S1> _suffix;
  final Iterable<GetResult<S>> Function(O) _to;
  final O Function(Iterable<S>) _from;

  TraversalInterface._(this._to, this._from, this._prefix, this._suffix);
  static TraversalInterface<C, O, O, S, S> mk<C extends Traversal<O, O, S>, O,
          S>(
    Iterable<GetResult<S>> Function(O) to,
    O Function(Iterable<S>) from,
  ) =>
      TraversalInterface._(to, from, Mutater.identity(), Mutater.identity());

  @override
  Zoom<C, S2> then<S2>(Zoom<Lens<S1>, S2> lens) {
    return this.thenMut(lens);
  }

  @override
  Zoom<C, S2> thenMut<S2>(Zoom<Mutater<S1>, S2> mutater) {
    return TraversalInterface._(_to, _from, _prefix, _suffix.thenMut(mutater));
  }

  @override
  MutResult<T> mutResult(T t, S1 Function(S1 s) f) {
    Set<Path<Object>> sMutateds = Set.identity();
    final tResult = this._prefix.mutResult(t, (o) {
      final resultO = this._from(this._to(o).map((s) {
        final sResult = this._suffix.mutResult(s.value, f);
        sMutateds.addAll(sResult.mutated.map((path) => s.path + path));
        return sResult.value;
      }));
      return resultO;
    });
    return MutResult(
      tResult.value,
      tResult.path,
      tResult.mutated
          .union(Set.of(sMutateds.map((path) => tResult.path + path))),
    );
  }

  @override
  Zoom<Mutater<T0>, S1> mutAfter<T0>(Zoom<Mutater<T0>, T> arg) {
    final TraversalInterface<Traversal<O, T0, S>, O, T0, S, S1> traversal =
        TraversalInterface._(_to, _from, _prefix.mutAfter(arg), _suffix);
    return traversal;
  }
}

abstract class Traversal<O, T, S> implements ThenLens, Mutater<T> {}
