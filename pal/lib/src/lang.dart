// ignore_for_file: constant_identifier_names

import 'serialize.dart';
import 'ast.dart';

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

final TypeCtx coreTypeCtx = IDMap({Type.id: const Ann(Type, Type)});
