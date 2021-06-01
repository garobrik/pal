import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'reified_lenses.g.dart';

typedef PathMap<V> = TrieMap<Object, V>;
typedef PathMapSet<V> = TrieMapSet<Object, V>;
typedef PathSet = TrieSet<Object>;
typedef Path = Iterable<Object>;

@immutable
@reify
class Diff with _DiffMixin {
  final PathSet changed;
  final PathSet removed;
  final PathSet added;

  const Diff({
    this.changed = const PathSet.empty(),
    this.removed = const PathSet.empty(),
    this.added = const PathSet.empty(),
  });

  const Diff.allChanged()
      : this.changed = const PathSet.root(),
        this.removed = const PathSet.empty(),
        this.added = const PathSet.empty();

  Diff prepend(Path path) => Diff(
        added: added.prepend(path),
        changed: changed.prepend(path),
        removed: removed.prepend(path),
      );

  Diff union(Diff other) => Diff(
        changed: changed.union(other.changed),
        added: added.union(other.added),
        removed: removed.union(other.removed),
      );

  Diff atPrefix(Path path) => Diff(
        added: added.atPrefix(path),
        changed: changed.atPrefix(path),
        removed: removed.atPrefix(path),
      );
}

@immutable
class DiffResult<T> {
  final T value;
  final Diff diff;

  const DiffResult(this.value, this.diff);
  const DiffResult.same(this.value) : diff = const Diff();
  const DiffResult.allChanged(this.value) : diff = const Diff.allChanged();
}

@immutable
class PathResult<T> {
  final T value;
  final Path path;

  const PathResult(this.value, this.path);
}

typedef GetterF<T, S> = S Function(T);

typedef MutaterF<T, S> = T Function(T, TransformF<S>);

typedef SetterF<T, S> = T Function(T, S);

typedef TransformF<T> = T Function(T);

abstract class Getter<T, S> {
  const factory Getter(Path path, GetterF<T, S> _getter) = _GetterImpl;
  const factory Getter.identity() = _IdentityImpl;
  const factory Getter.mkCast() = _CastImpl;

  S get(T t);
  Path get path;

  Getter<T, S2> thenGet<S2>(Getter<S, S2> getter) {
    return Getter(path.followedBy(getter.path), (t) => getter.get(get(t)));
  }

  Getter<T, S2> then<S2>(Lens<S, S2> getter);

  Getter<T, S2> cast<S2>() => thenGet(Getter<S, S2>.mkCast());
}

@immutable
abstract class Lens<T, S> implements Getter<T, S> {
  const factory Lens(Path path, GetterF<T, S> getF, MutaterF<T, S> mutF) = _LensImpl;
  const factory Lens.mkCast() = _CastImpl;
  static Lens<T, T> identity<T>() => _IdentityImpl();

  T mut(T t, S Function(S) s);

  DiffResult<T> mutDiff(T t, DiffResult<S> Function(S) f) {
    late Diff diff;
    final newT = mut(t, (s) {
      final result = f(s);
      diff = result.diff;
      return result.value;
    });
    return DiffResult(newT, diff.prepend(path));
  }

  @override
  Lens<T, S2> then<S2>(Lens<S, S2> lens) => Lens(
        path.followedBy(lens.path),
        (t) => lens.get(get(t)),
        (t, f) => mut(t, (s) => lens.mut(s, f)),
      );

  @override
  Getter<T, S2> thenGet<S2>(Getter<S, S2> getter) => Getter(
        path.followedBy(getter.path),
        (t) => getter.get(get(t)),
      );

  @override
  Lens<T, S2> cast<S2>() => then(Lens<S, S2>.mkCast());
}

@immutable
class _GetterImpl<T, S> with Getter<T, S> {
  final Path _path;
  final GetterF<T, S> _getter;

  const _GetterImpl(this._path, this._getter);

  @override
  Path get path => _path;

  @override
  S get(T t) => _getter(t);

  @override
  Getter<T, S2> then<S2>(Lens<S, S2> lens) => thenGet(lens);
}

@immutable
class _LensImpl<T, S> with Lens<T, S> {
  final Path _path;
  final GetterF<T, S> _getF;
  final MutaterF<T, S> _mutF;

  const _LensImpl(this._path, this._getF, this._mutF);

  @override
  Path get path => _path;

  @override
  S get(T t) => _getF(t);

  @override
  T mut(T t, S Function(S) f) => _mutF(t, f);
}

@immutable
class _IdentityImpl<T> implements Getter<T, T>, Lens<T, T> {
  const _IdentityImpl();

  @override
  Path get path => const [];

  @override
  T get(T t) => t;

  @override
  Lens<T, S2> then<S2>(Lens<T, S2> lens) => lens;

  @override
  Getter<T, S2> thenGet<S2>(Getter<T, S2> getter) => getter;

  @override
  Lens<T, S2> cast<S2>() => Lens<T, S2>.mkCast();

  @override
  T mut(T t, T Function(T) f) => f(t);

  @override
  DiffResult<T> mutDiff(T t, DiffResult<T> Function(T p1) f) => f(t);
}

class _CastImpl<T, S> with Getter<T, S>, Lens<T, S> {
  const _CastImpl();

  @override
  Path get path => const [];

  @override
  S get(T t) => t as S;

  @override
  Lens<T, S2> cast<S2>() => Lens<T, S2>.mkCast();

  @override
  T mut(T t, S Function(S) f) => f(t as S) as T;
}

extension GetterNullability<T, S> on Getter<T, S?> {
  Getter<T, S> get nonnull => thenGet(Getter(const [], (s) => s!));
}

extension LensNullability<T, S> on Lens<T, S?> {
  Lens<T, S> get nonnull => then(Lens(const [], (s) => s!, (s, f) => f(s!)));
}
