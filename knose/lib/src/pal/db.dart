import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:uuid/uuid.dart';

part 'db.g.dart';

@reify
class DB with _DBMixin {
  @override
  final Dict<String, Dict<String, Object>> cache;

  const DB([this.cache = const Dict()]);

  DB merge(DB other) {
    return DB(cache.merge(other.cache, onConflict: (a, b) => a.merge(b)));
  }

  @override
  String toString() {
    return cache.toString();
  }
}

extension DBCursor on Cursor<DB> {
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

  Cursor<Optional<T>> get<T extends Object>(ID<T> id) {
    return cache[id._namespace].orElse(const Dict())[id._key].optionalCast<T>();
  }

  void update<T extends Object>(ID<T> id, T object) {
    cache[id._namespace].orElse(const Dict())[id._key] = object;
  }
}

class ID<T extends Object> {
  static const _uuid = Uuid();

  final String _namespace;
  final String _key;

  ID.create({required String namespace})
      : _namespace = namespace,
        _key = _uuid.v4();
  const ID.from(this._namespace, this._key);

  @override
  String toString() => 'PalID($_namespace: $_key)';
}

class _DBCtxElement extends CtxElement {
  final Cursor<DB> palDB;

  _DBCtxElement(this.palDB);
}

extension DBCtxExtension on Ctx {
  Ctx withDB(Cursor<DB> db) => withElement(_DBCtxElement(db));
  Cursor<DB> get db => get<_DBCtxElement>()!.palDB;
}
