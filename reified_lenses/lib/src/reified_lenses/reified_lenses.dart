import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'reified_lenses.g.dart';

typedef PathSet = TrieSet<Object>;
typedef Path = Vec<Object>;

PathSet atPrefixWithParent(PathSet pathSet, Path prefix) {
  for (final pathElem in prefix) {
    if (pathSet.containsRoot) return PathSet.root();
    pathSet = pathSet.atPrefix(Vec([pathElem]));
  }
  return pathSet;
}

@immutable
@reify
class Diff with _DiffMixin, ToStringCtx {
  @override
  final PathSet changed;
  @override
  final PathSet removed;
  @override
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

  bool get isEmpty => changed.isEmpty && removed.isEmpty && added.isEmpty;
  bool get isNotEmpty => !isEmpty;

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
        added: atPrefixWithParent(added, path),
        changed: atPrefixWithParent(changed, path),
        removed: atPrefixWithParent(removed, path),
      );

  PathSet allPaths() => added.union(changed).union(removed);

  @override
  void doStringCtx(StringBuffer buffer, int leading) {
    buffer.writeln('Diff(');
    buffer.write('  changed:'.padLeft(leading));
    changed.doStringCtx(buffer, leading + 2);
    buffer.writeln(',');
    buffer.write('  added:'.padLeft(leading));
    added.doStringCtx(buffer, leading + 2);
    buffer.writeln(',');
    buffer.write('  removed:'.padLeft(leading));
    removed.doStringCtx(buffer, leading + 2);
    buffer.writeln(')');
  }
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

typedef OptGetterF<T, S> = Optional<S> Function(T);

typedef GetterF<T, S> = S Function(T);

typedef MutaterF<T, S> = T Function(T, TransformF<S>);

typedef SetterF<T, S> = T Function(T, S);

typedef TransformF<T> = T Function(T);

@immutable
abstract class OptGetter<T, S> {
  const factory OptGetter(Path path, OptGetterF<T, S> getter) = _OptGetterImpl;

  Path get path;
  Optional<S> getOpt(T t);
}

@immutable
abstract class Getter<T, S> implements OptGetter<T, S> {
  const factory Getter(Path path, GetterF<T, S> getter) = _GetterImpl;
  static Getter<S, S> identity<S>() => _IdentityImpl();

  S get(T t);

  @override
  Optional<S> getOpt(T t) => Optional(get(t));
}

@immutable
abstract class OptLens<T, S> implements OptGetter<T, S> {
  const factory OptLens(Path path, OptGetterF<T, S> getF, MutaterF<T, S> mutF) = _OptLensImpl;
  T mut(T t, S Function(S) f);
}

@immutable
abstract class Lens<T, S> implements Getter<T, S>, OptLens<T, S> {
  const factory Lens(Path path, GetterF<T, S> getF, MutaterF<T, S> mutF) = _LensImpl;
  static Lens<T, T> identity<T>() => _IdentityImpl();

  @override
  Optional<S> getOpt(T t) => Optional(get(t));
}

extension OptGetterCompositions<T, S> on OptGetter<T, S> {
  OptGetter<T, S2> then<S2>(OptGetter<S, S2> getter) =>
      OptGetter(path.append(getter.path), (t) => getOpt(t).flatMap(getter.getOpt));
}

extension GetterCompositions<T, S> on Getter<T, S> {
  Getter<T, S2> then<S2>(Getter<S, S2> getter) =>
      Getter(path.append(getter.path), (t) => getter.get(get(t)));
}

extension OptLensCompositions<T, S> on OptLens<T, S> {
  OptLens<T, S2> then<S2>(OptLens<S, S2> lens) => OptLens(
        path.append(lens.path),
        (t) => getOpt(t).flatMap(lens.getOpt),
        (t, f) => mut(t, (s) => lens.mut(s, f)),
      );

  DiffResult<T> mutDiff(T t, DiffResult<S> Function(S) f) {
    Diff diff = const Diff();
    final newT = mut(t, (s) {
      final result = f(s);
      diff = result.diff;
      return result.value;
    });
    return DiffResult(newT, diff.prepend(path));
  }
}

extension LensCompositions<T, S> on Lens<T, S> {
  Lens<T, S2> then<S2>(Lens<S, S2> lens) => Lens(
        path.append(lens.path),
        (t) => lens.get(get(t)),
        (t, f) => mut(t, (s) => lens.mut(s, f)),
      );
}

@immutable
class _OptGetterImpl<T, S> with OptGetter<T, S> {
  final Path _path;
  final OptGetterF<T, S> _getter;

  const _OptGetterImpl(this._path, this._getter);

  @override
  Path get path => _path;

  @override
  Optional<S> getOpt(T t) => _getter(t);
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
}

@immutable
class _OptLensImpl<T, S> with OptLens<T, S> {
  final Path _path;
  final OptGetterF<T, S> _getF;
  final MutaterF<T, S> _mutF;

  const _OptLensImpl(this._path, this._getF, this._mutF);

  @override
  Path get path => _path;

  @override
  Optional<S> getOpt(T t) => _getF(t);

  @override
  T mut(T t, S Function(S) f) => _mutF(t, f);
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
  _IdentityImpl();

  @override
  Path get path => const Vec();

  @override
  T get(T t) => t;

  @override
  Optional<T> getOpt(T t) => Optional(t);

  @override
  T mut(T t, T Function(T) f) => f(t);
}
