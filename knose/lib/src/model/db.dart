import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:uuid/uuid.dart';

part 'db.g.dart';

@reify
class PalDB with _PalDBMixin {
  @override
  final Dict<String, Dict<String, Object>> cache;

  const PalDB([this.cache = const Dict()]);
}

extension PalDBCursor on Cursor<PalDB> {
  Optional<Cursor<T>> find<T extends Object>({
    required Ctx ctx,
    required String namespace,
    required bool Function(Cursor<T>) predicate,
  }) {
    final map = cache[namespace].orElse(const Dict());
    for (final key in map.keys.read(ctx)) {
      final obj = map[key].whenPresent.cast<T>();
      if (predicate(obj)) {
        return Optional(obj);
      }
    }
    // ignore: prefer_const_constructors, Optional<Cursor<Never>> doesn't subtype Optional<Cursor<T>>
    return Optional.none();
  }

  Iterable<Cursor<T>> where<T extends Object>({
    required Ctx ctx,
    required String namespace,
    required bool Function(Cursor<T>) predicate,
  }) sync* {
    final map = cache[namespace].orElse(const Dict());
    for (final key in map.keys.read(ctx)) {
      final obj = map[key].whenPresent.cast<T>();
      if (predicate(obj)) {
        yield obj;
      }
    }
  }

  Cursor<Optional<T>> get<T extends Object>(PalID<T> id) {
    return cache[id._namespace].orElse(const Dict())[id._key].optionalCast<T>();
  }

  void update<T extends Object>(PalID<T> id, T object) {
    cache[id._namespace].orElse(const Dict())[id._key] = Optional(object);
  }
}

class PalID<T extends Object> {
  static const _uuid = Uuid();

  final String _namespace;
  final String _key;

  PalID.create({required String namespace})
      : _namespace = namespace,
        _key = _uuid.v4();
  const PalID.from(this._namespace, this._key);

  @override
  String toString() => 'PalID($_namespace: $_key)';
}

class _PalDBCtxElement extends CtxElement {
  final Cursor<PalDB> palDB;

  _PalDBCtxElement(this.palDB);
}

extension PalDBCtxExtension on Ctx {
  Ctx withDB(Cursor<PalDB> db) => withElement(_PalDBCtxElement(db));
  Cursor<PalDB> get db => get<_PalDBCtxElement>()!.palDB;
}
