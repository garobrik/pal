// ignore_for_file: constant_identifier_names

import 'serialize.dart';

typedef Program = List<List<Binding>>;

typedef ID = String;

extension IDExtension on ID {}

extension on Iterable<ID> {
  static ID _freshen(ID id) => id.replaceFirstMapped(
        RegExp('[0-9]*\$'),
        (match) => ((int.tryParse(match[0]!) ?? 0) + 1).toString(),
      );

  ID freshen(ID id) {
    while (contains(id)) {
      id = _freshen(id);
    }
    return id;
  }
}

class Binding<T extends Object> {
  final ID id;
  final Expr<T>? type;
  final Expr<T>? value;

  const Binding(this.id, this.type, this.value) : assert(type != null || value != null);
}

sealed class Expr<T extends Object> {
  final T? t;
  const Expr({this.t});

  @override
  String toString() => serializeExprIndent(80);

  @override
  bool operator ==(Object other) => other is Expr && this.alphaEquiv(other);

  int _hashCode(List<String?> ctx) => switch (this) {
        Var v => Hash.all([!ctx.contains(v.id) ? v.id.hashCode : ctx.indexOf(v.id).hashCode]),
        App app => Hash.all([app.implicit.hashCode, app.fn._hashCode(ctx), app.arg._hashCode(ctx)]),
        Fn fn => Hash.all([
            fn.implicit.hashCode,
            fn.kind.hashCode,
            fn.argType._hashCode(ctx),
            fn.result._hashCode([fn.argID, ...ctx])
          ]),
      };

  @override
  int get hashCode => _hashCode(const []);
}

class Var<T extends Object> extends Expr<T> {
  final ID id;

  const Var(this.id, {super.t});
}

class App<T extends Object> extends Expr<T> {
  final bool implicit;
  final Expr<T> fn;
  final Expr<T> arg;

  const App(this.implicit, this.fn, this.arg, {super.t});
}

enum FnKind { Def, Typ }

class Fn<T extends Object> extends Expr<T> {
  static const Def = FnKind.Def;
  static const Typ = FnKind.Typ;

  final FnKind kind;
  final bool implicit;
  final ID? argID;
  final Expr<T> argType;
  final Expr<T> result;

  const Fn(this.implicit, this.kind, this.argID, this.argType, this.result, {super.t});
  const Fn.def(this.implicit, this.argID, this.argType, this.result, {super.t}) : kind = FnKind.Def;
  const Fn.typ(this.implicit, this.argID, this.argType, this.result, {super.t}) : kind = FnKind.Typ;
}

extension ExprOps<T extends Object> on Expr<T> {
  Set<ID> get freeVars => switch (this) {
        Var(:var id) => {id},
        Fn(:var argID, :var result, :var argType) =>
          result.freeVars.difference({argID}).union(argType.freeVars),
        App(:var fn, :var arg) => fn.freeVars.union(arg.freeVars),
      };

  bool occurs(Var v) => switch (this) {
        Var(:var id) => v.id == id,
        App(:var fn, :var arg) => fn.occurs(v) || arg.occurs(v),
        Fn(:var argID, :var argType, :var result) =>
          argType.occurs(v) || (v.id != argID && result.occurs(v))
      };

  Expr<T> substExpr(ID from, Expr<T> to) {
    switch (this) {
      case Var(:var id):
        return id == from ? to : this;
      case App(:var implicit, :var fn, :var arg):
        return App(implicit, fn.substExpr(from, to), arg.substExpr(from, to));
      case Fn(:var implicit, :var kind, :var argID, :var argType, :var result):
        if (argID == from) {
          return Fn(implicit, kind, argID, argType.substExpr(from, to), result);
        } else if (argID == null) {
          return Fn(implicit, kind, argID, argType.substExpr(from, to), result.substExpr(from, to));
        }
        var newArgID = to.freeVars.difference({argID}).freshen(argID);

        if (argID != newArgID) result = result.substExpr(argID, Var(newArgID));

        return Fn(
          implicit,
          kind,
          newArgID,
          argType.substExpr(from, to),
          result.substExpr(from, to),
        );
    }
  }

  bool alphaEquiv(Expr b, [List<String?> ctxA = const [], List<String?> ctxB = const []]) =>
      switch ((this, b)) {
        (Var(id: var a), Var(id: var b)) =>
          ctxA.indexOf(a) == ctxB.indexOf(b) && (ctxA.contains(a) || (a == b)),
        (App a, App b) => a.implicit == b.implicit &&
            a.fn.alphaEquiv(b.fn, ctxA, ctxB) &&
            a.arg.alphaEquiv(b.arg, ctxA, ctxB),
        (Fn a, Fn b) => a.implicit == b.implicit &&
            a.kind == b.kind &&
            a.argType.alphaEquiv(b.argType, ctxA, ctxB) &&
            a.result.alphaEquiv(b.result, [a.argID, ...ctxA], [b.argID, ...ctxB]),
        _ => false,
      };
}

const typeID = 'Type';
const Type = Var(typeID);
const TypeCtx coreTypeCtx = IDMap({typeID: Ann(Type, Type)});

// Type Checking

extension type const IDMap<T>(Map<ID, T> map) {
  static IDMap<T> empty<T>() => const IDMap({});

  Iterable<ID> get keys => map.keys;
  bool get isEmpty => map.isEmpty;
  T? get(ID key) => map[key];
  IDMap<T> add(ID key, T value) => IDMap({...map, key: value});
  IDMap<T> union(IDMap<T> other) => IDMap({...map, ...other.map});
  IDMap<T> without(ID key) {
    final newMap = {...map};
    newMap.remove(key);
    return IDMap(newMap);
  }

  bool containsKey(ID key) => map.containsKey(key);

  bool equals(IDMap<T> other) {
    if (map.length != other.map.length) return false;
    for (final MapEntry(:key, :value) in map.entries) {
      if (other.get(key) != value) return false;
    }
    return true;
  }

  IDMap<T> restrict(Iterable<ID> ids) => IDMap({
        for (final id in ids)
          if (this.containsKey(id)) id: this.get(id) as T
      });

  IDMap<T> filter(bool Function(ID, T) f) => IDMap({
        for (final entry in map.entries)
          if (f(entry.key, entry.value)) entry.key: entry.value
      });
}

class Ann<T extends Object> {
  final Expr<T>? type;
  final Expr<T>? value;

  const Ann(this.type, this.value);
  const Ann.empty()
      : type = null,
        value = null;

  @override
  String toString() {
    final valueStr = switch (value) { Var(:var id) => id, _ => value?.toString() };
    final typeStr = switch (type) { Var(:var id) => id, _ => type?.toString() };
    return '$valueStr: $typeStr';
  }
}

class Jdg<T extends Object> {
  final Expr<T>? type;
  final Expr<T> value;

  const Jdg(this.type, this.value);

  @override
  String toString() {
    final valueStr = switch (value) { Var(:var id) => id, _ => value.toString() };
    final typeStr = switch (type) { Var(:var id) => id, _ => type.toString() };
    return '$valueStr: $typeStr';
  }
}

typedef TypeCtx<T extends Object> = IDMap<Ann>;

sealed class Result<T> {
  const Result();

  Result<T2> map<T2>(
    bool gotMore,
    String? ctx,
    Result<T2> Function(T result, TypeCtx ctx, bool gotMore) f,
  ) =>
      switch (this) {
        Progress<T> p => f(p.result, p.ctx, gotMore || p.gotMore),
        Failure<T> f => f.wrap(ctx),
      };
}

class Progress<T> extends Result<T> {
  final T result;
  final TypeCtx ctx;
  final bool gotMore;

  const Progress(this.result, this.ctx, this.gotMore);
  const Progress.more(this.result, this.ctx) : gotMore = true;
  const Progress.same(this.result, this.ctx) : gotMore = false;

  @override
  String toString() => '$result, $gotMore';
}

class Failure<T> extends Result<T> {
  final String reason;

  const Failure(this.reason);

  Failure<T2> wrap<T2>([String? ctx]) => ctx == null ? Failure(reason) : Failure(reason.wrap(ctx));

  @override
  String toString() => '''
Failure:
$reason
''';
}

Result<Jdg> check(TypeCtx ctx, Expr? expectedType, Expr expr) {
  final expectedTypeVar = Var([...ctx.keys, ...expr.freeVars].freshen('EXPECTED_TYPE'));
  final result = unify(
    ctx,
    expectedType ?? expectedTypeVar,
    null,
    expr,
  );
  if (result case Progress(ctx: var subCtx, result: Jdg(:var type, :var value))) {
    subCtx.filter((_, ann) => ann.value == Type).keys.forEach((k) {
      type = type?.substExpr(k, Type);
      value = value.substExpr(k, Type);
    });
    assert(type != null && type!.freeVars.every((v) => ctx.containsKey(v)), type.toString());
    assert(value.freeVars.every((v) => ctx.containsKey(v)), value.toString());
    return Progress.same(Jdg(type, value), subCtx);
  }
  return result;
}

Result<Jdg> unify(TypeCtx ctx, Expr? expectedType, Expr? expected, Expr expr) {
  Result<Jdg> unifyStep(TypeCtx ctx, Expr expr) {
    switch ((expected, expr)) {
      case (null || Type, Type):
        return Progress.same(const Jdg(Type, Type), ctx);

      case (_, Var expr) when ctx.get(expr.id)?.value != null && ctx.get(expr.id)?.value != Type:
        return unify(ctx, expectedType, expected, ctx.get(expr.id)!.value!);

      case (Var expected, _)
          when ctx.get(expected.id)?.value != null && ctx.get(expected.id)?.value != Type:
        return unify(ctx, expectedType, ctx.get(expected.id)!.value!, expr);

      case (Expr? expected, Var expr):
        if (expected?.occurs(expr) ?? false) {
          return Failure('cycle: $expected in $expr');
        }
        var type = ctx.get(expr.id)?.type;
        if ((type == null || type == Type) && expectedType != null) type = expectedType;
        return Progress(
          Jdg(type, expected ?? expr),
          ctx.add(expr.id, Ann(type, expected)),
          expected != null || type != ctx.get(expr.id)?.type,
        );

      case (Var expected, Expr expr):
        if (expr.occurs(expected)) {
          return Failure('cycle: $expr in $expected');
        }
        var type = ctx.get(expected.id)?.type;
        if (type == null || type == Type) type = expectedType;
        return Progress.more(Jdg(type, expr), ctx.add(expected.id, Ann(type, expr)));

      case (App? expected, App expr):
        final errCtx = StringBuffer('arg${expected != null ? 's' : ''} of:\n');
        if (expected != null) errCtx.writeln(expected.arg.toString().indent);
        errCtx.write(expr.arg.toString().indent);

        return unify(ctx, null, expected?.arg, expr.arg).map(false, errCtx.toString(),
            (arg, ctx, gotMore) {
          final fnType = arg.type != null && expectedType != null
              ? Fn.typ(false, null, arg.type!, expectedType)
              : null;

          final errCtx = StringBuffer('fn${expected != null ? 's' : ''} of:\n');
          if (expected != null) errCtx.writeln(expected.fn.toString().indent);
          errCtx.write(expr.fn.toString().indent);

          return unify(ctx, fnType, expected?.fn, expr.fn).map(gotMore, errCtx.toString(),
              (fn, ctx, gotMore) {
            Expr? type = expectedType;
            if (fn.type case Fn(:var argID, :var result)) {
              type = argID != null ? result.substExpr(argID, arg.value) : result;
            }

            Expr value = App(expr.implicit, fn.value, arg.value);
            if (fn.value case Fn(:var argID, :var result)) {
              value = argID != null ? result.substExpr(argID, arg.value) : result;
            }

            return Progress(Jdg(type, value), ctx, gotMore);
          });
        });

      case (Fn? expected, Fn expr) when expected == null || expected.kind == expr.kind:
        final errCtx = StringBuffer('arg${expected != null ? 's' : ''} of:\n');
        if (expected != null) errCtx.writeln(expected.argType.toString().indent);
        errCtx.write(expr.argType.toString().indent);

        return unify(ctx, Type, expected?.argType, expr.argType).map(false, '$errCtx',
            (argType, ctx, gotMore) {
          final argID = expected?.argID ?? expr.argID;
          final resultType = expr.kind == Fn.Typ
              ? Type
              : expectedType is Fn
                  ? expectedType.result
                  : null;

          final errCtx = StringBuffer('result${expected != null ? 's' : ''} of:\n');
          if (expected != null) errCtx.writeln(expected.result.toString().indent);
          errCtx.write(expr.result.toString().indent);

          return unify(
            argID == null ? ctx : ctx.add(argID, Ann(argType.value, null)),
            resultType,
            expected?.result,
            expr.result,
          ).map(gotMore, '$errCtx', (result, ctx, gotMore) {
            var jdg = Jdg(
              expr.kind == Fn.Typ
                  ? Type
                  : result.type == null
                      ? null
                      : Fn.typ(expr.implicit, argID, argType.value, result.type!),
              Fn(expr.implicit, expr.kind, argID, argType.value, result.value),
            );

            return Progress(jdg, ctx, gotMore);
          });
        });
      case _:
        return Failure('can\'t unify:\n  $expected\n  $expr');
    }
  }

  bool gotAnyMore = false;
  bool gotMore = true;
  Expr? resultType;
  while (gotMore) {
    if (expected != null && expected.alphaEquiv(expr)) {
      return unify(ctx, null, null, expr);
    }
    final result = unifyStep(ctx, expr);
    if (result is Failure<Jdg>) return result;
    Progress(result: Jdg(type: resultType, value: expr), :gotMore, :ctx) = result as Progress<Jdg>;

    if (expectedType != null && resultType != null) {
      final unifyResult = unify(ctx, Type, expectedType, resultType);
      if (unifyResult is Failure<Jdg>) {
        return Failure(unifyResult.reason.wrap('checking expected type in:\n$expr'));
      }
      Progress(result: Jdg(value: resultType), :gotMore, :ctx) = unifyResult as Progress<Jdg>;
      gotMore = unifyResult.gotMore || gotMore;
    }

    resultType = resultType == null ? null : reduce(ctx, resultType);
    expr = reduce(ctx, expr);
    gotAnyMore = gotAnyMore || gotMore;
  }
  return Progress(Jdg(resultType, expr), ctx, gotAnyMore);
}

Expr reduce(TypeCtx ctx, Expr expr) => switch (expr) {
      Var expr => switch (ctx.get(expr.id)) {
          Ann(value: var redex) when redex != Type && redex != null => reduce(ctx, redex),
          _ => expr,
        },
      App expr => switch (reduce(ctx, expr.fn)) {
          Fn(kind: Fn.Def, :var argID, result: var body) =>
            reduce(ctx, argID != null ? body.substExpr(argID, reduce(ctx, expr.arg)) : body),
          var fn => App(expr.implicit, fn, reduce(ctx, expr.arg)),
        },
      Fn expr => Fn(expr.implicit, expr.kind, expr.argID, reduce(ctx, expr.argType),
          reduce(ctx, expr.result)),
    };

extension on String {
  String wrap(String ctx) => ctx.isEmpty ? this : '$ctx\n\n$this';
}

class Hash {
  static int combine(int hash, int value) {
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  static int all(List<int> hashes) => finish(hashes.fold(0, combine));
}
