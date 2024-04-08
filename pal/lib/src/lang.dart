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

Result<Jdg> check(TypeCtx origCtx, Expr? origExpectedType, Expr origExpr) {
  late Result<Jdg> Function(TypeCtx ctx, Expr expectedType, Expr expected, Expr expr) unify;

  Result<Jdg> doCheck(TypeCtx ctx, Expr? expectedType, Expr expr) {
    Result<Jdg> checkStep(TypeCtx ctx, Expr? expectedType, Expr expr) {
      switch (expr) {
        case Var expr:
          final binding = ctx.get(expr.id);
          bool gotMore = false;
          if (expectedType != null) {
            if (binding?.type == null) {
              ctx = ctx.add(expr.id, Ann(expectedType, binding?.value));
              gotMore = true;
            } else {
              return unify(ctx, Type, expectedType, binding!.type!).map(false, null,
                  (varType, ctx, gotMore) {
                return Progress(Jdg(varType.value, binding.value ?? expr), ctx, gotMore);
              });
            }
          }
          return Progress(Jdg(binding?.type ?? expectedType, binding?.value ?? expr), ctx, gotMore);

        case App expr:
          final errCtx = 'fn of:\n${expr.toString().indent}';

          return doCheck(ctx, null, expr.fn).map(false, errCtx.toString(), (fn, ctx, gotMore) {
            final errCtx = 'arg of:\n${expr.toString().indent}';
            Expr? expectedType;
            if (fn.value case Fn(:var argType)) {
              expectedType = argType;
            } else if (fn.type case Fn(:var argType)) {
              expectedType = argType;
            }

            return doCheck(ctx, expectedType, expr.arg).map(gotMore, errCtx.toString(),
                (arg, ctx, gotMore) {
              Expr value = App(expr.implicit, fn.value, arg.value);
              if (fn.value case Fn(:var argID, :var result)) {
                value = argID != null ? result.substExpr(argID, arg.value) : result;
              }
              if (fn.type case Fn(:var argID, :var argType, :var result)) {
                if (arg.type != null) {
                  final errCtx = 'checking arg type in:\n${expr.toString().indent}';
                  return unify(ctx, Type, argType, arg.type!).map(gotMore, errCtx,
                      (argType, ctx, gotMore) {
                    return Progress(
                      Jdg(argID != null ? result.substExpr(argID, arg.value) : result, value),
                      ctx,
                      gotMore,
                    );
                  });
                }
              }
              return Progress(Jdg(expectedType, value), ctx, gotMore);
            });
          });

        case Fn expr:
          final errCtx = 'arg of:\n${expr.toString().indent}';

          return doCheck(ctx, Type, expr.argType).map(false, errCtx, (argType, ctx, gotMore) {
            if (expectedType case Fn(argType: var expectedArgType)) {
              final result = unify(ctx, Type, expectedArgType, argType.value);
              if (result is Failure<Jdg>) return result;
              if (result is! Progress<Jdg>) throw Exception();
              Progress(result: argType, :ctx) = result;
              gotMore = gotMore || result.gotMore;
            }

            ID? argID = expr.argID;
            Expr? expectedResultType;
            Expr exprResult = expr.result;
            if (expectedType case Fn expectedType) {
              if (expectedType.argID != null && expr.argID != null) {
                argID =
                    [...ctx.keys, ...expectedType.freeVars, ...expr.freeVars].freshen(expr.argID!);
                expectedResultType = expectedType.result.substExpr(expectedType.argID!, Var(argID));
                exprResult = exprResult.substExpr(expr.argID!, Var(argID));
              }
            }

            final errCtx = 'result of:\n${expr.toString().indent}';
            final oldArgBinding = argID == null ? null : ctx.get(argID);

            return doCheck(
              argID == null ? ctx : ctx.add(argID, Ann(argType.value, null)),
              expr.kind == Fn.Typ ? Type : expectedResultType,
              expr.result,
            ).map(gotMore, errCtx, (result, ctx, gotMore) {
              final jdg = Jdg(
                expr.kind == Fn.Typ
                    ? Type
                    : result.type == null
                        ? null
                        : Fn.typ(expr.implicit, argID, argType.value, result.type!),
                Fn(expr.implicit, expr.kind, argID, argType.value, result.value),
              );

              if (argID != null) {
                ctx = ctx.without(argID);
                if (oldArgBinding != null) {
                  ctx = ctx.add(argID, oldArgBinding);
                }
              }
              return Progress(jdg, ctx, gotMore);
            });
          });
      }
    }

    bool gotAnyMore = false;
    bool gotMore = true;
    Expr? resultType;
    while (gotMore) {
      final result = checkStep(ctx, expectedType, expr);
      if (result is Failure<Jdg>) return result;
      Progress(result: Jdg(type: resultType, value: expr), :gotMore, :ctx) =
          result as Progress<Jdg>;

      if (expectedType != null && resultType != null) {
        final unifyResult = unify(ctx, Type, expectedType, resultType);
        if (unifyResult is Failure<Jdg>) {
          return Failure(unifyResult.reason.wrap('checking expected type in:\n$expr'));
        }
        Progress(result: Jdg(value: resultType), :gotMore, :ctx) = unifyResult as Progress<Jdg>;
        gotMore = unifyResult.gotMore || gotMore;
      }

      expectedType = expectedType == null ? null : reduce(ctx, expectedType);
      resultType = resultType == null ? null : reduce(ctx, resultType);
      expr = reduce(ctx, expr);
      gotAnyMore = gotAnyMore || gotMore;
    }
    return Progress(Jdg(resultType, expr), ctx, gotAnyMore);
  }

  unify = (TypeCtx ctx, Expr expectedType, Expr expected, Expr expr) {
    if (expected.alphaEquiv(expr)) return Progress.same(Jdg(expectedType, expr), ctx);
    switch ((expected, expr)) {
      case (_, Var expr) when ctx.get(expr.id)?.value != null && ctx.get(expr.id)?.value != Type:
        return unify(ctx, expectedType, expected, ctx.get(expr.id)!.value!);

      case (Var expected, _)
          when ctx.get(expected.id)?.value != null && ctx.get(expected.id)?.value != Type:
        return unify(ctx, expectedType, ctx.get(expected.id)!.value!, expr);

      case (Var expected, Var expr)
          when !origExpr.freeVars.contains(expr.id) && origExpr.freeVars.contains(expected.id):
        return unify(ctx, expectedType, expr, expected);

      case (_, Var expr) when expr != Type:
        if (expected.occurs(expr)) {
          return Failure('cycle: $expected in $expr');
        }
        var type = ctx.get(expr.id)?.type;
        if ((type == null || type == Type)) type = expectedType;
        return Progress(
          Jdg(type, expected),
          ctx.add(expr.id, Ann(type, expected)),
          type != ctx.get(expr.id)?.type,
        );

      case (Var expected, _):
        if (expr.occurs(expected)) {
          return Failure('cycle: $expr in $expected');
        }
        var type = ctx.get(expected.id)?.type;
        if (type == null || type == Type) type = expectedType;
        return Progress(
          Jdg(type, expr),
          ctx.add(expected.id, Ann(type, expr)),
          type != ctx.get(expected.id)?.type,
        );

      case (_, Type):
        return Progress.same(Jdg(Type, expected), ctx);
      case (Type, _):
        return Progress.same(Jdg(Type, expr), ctx);

      case (App expected, App expr):
        final errCtx = 'fn of:\n${expected.toString().indent}';

        return doCheck(ctx, null, expected.fn).map(false, errCtx.toString(),
            (expectedFn, ctx, gotMore) {
          final errCtx = 'fn of:\n${expected.toString().indent}';

          return doCheck(ctx, null, expected.fn).map(gotMore, errCtx.toString(),
              (exprFn, ctx, gotMore) {
            if ((expectedFn.type, exprFn.type) case (Fn expectedFn, Fn exprFn)) {
              if (expectedFn.alphaEquiv(exprFn)) {
                final errCtx = 'args of:\n${expected.toString().indent}\n${expr.toString().indent}';
                return unify(ctx, exprFn.argType, expected.arg, expr.arg)
                    .map(false, errCtx.toString(), (arg, ctx, gotMore) {
                  return Progress(
                      Jdg(
                        exprFn.argID == null
                            ? exprFn.result
                            : exprFn.result.substExpr(exprFn.argID!, arg.value),
                        App(expr.implicit, expr.fn, arg.value),
                      ),
                      ctx,
                      gotMore);
                });
              }
            }
            return Progress(Jdg(expectedType, expr), ctx, gotMore);
          });
        });

      case (Fn expected, Fn expr) when expected.kind == Fn.Typ && expr.kind == Fn.Typ:
        final errCtx = 'args of:\n${expected.toString().indent}\n${expr.toString().indent}';

        return unify(ctx, Type, expected.argType, expr.argType).map(false, errCtx,
            (argType, ctx, gotMore) {
          ID? argID;
          Expr expectedResult = expected.result;
          Expr exprResult = expr.result;
          if (expected.argID != null && expr.argID != null) {
            argID = [...ctx.keys, ...expected.freeVars, ...expr.freeVars].freshen(expr.argID!);
            expectedResult = expectedResult.substExpr(expected.argID!, Var(argID));
            exprResult = exprResult.substExpr(expr.argID!, Var(argID));
          }

          final errCtx = 'results of:\n${expected.toString().indent}\n${expr.toString().indent}';

          final oldArgBinding = argID == null ? null : ctx.get(argID);

          return unify(
            argID == null ? ctx : ctx.add(argID, Ann(argType.value, null)),
            Type,
            expectedResult,
            exprResult,
          ).map(gotMore, errCtx, (result, ctx, gotMore) {
            var jdg = Jdg(
              Type,
              Fn(expr.implicit, expr.kind, argID, argType.value, result.value),
            );

            if (argID != null) {
              ctx = ctx.without(argID);
              if (oldArgBinding != null) {
                ctx.add(argID, oldArgBinding);
              }
            }
            return Progress(jdg, ctx, gotMore);
          });
        });
      case _:
        return Failure('can\'t unify:\n  $expected\n  $expr');
    }
  };

  final result = doCheck(origCtx, origExpectedType, origExpr);
  if (result case Progress(:var ctx, result: Jdg(:var type, :var value))) {
    ctx.filter((_, ann) => ann.value == Type).keys.forEach((k) {
      type = type?.substExpr(k, Type);
      value = value.substExpr(k, Type);
    });
    assert(type != null && type!.freeVars.every((v) => ctx.containsKey(v)), type.toString());
    assert(value.freeVars.every((v) => ctx.containsKey(v)), value.toString());
    return Progress.same(Jdg(type, value), ctx);
  }
  return result;
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
