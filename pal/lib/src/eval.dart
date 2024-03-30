import 'dart:collection';

import 'lang.dart';

typedef EvalCtx = IDMap<Object?>;

class Closure {
  final EvalCtx ctx;
  final ID? argID;
  final Expr body;

  Closure(this.ctx, this.argID, this.body);

  @override
  String toString() => 'Closure($ctx, $argID, $body)';

  @override
  bool operator ==(Object other) =>
      other is Closure &&
      argID == other.argID &&
      body.alphaEquiv(other.body) &&
      ctx.equals(other.ctx);

  @override
  int get hashCode {
    final sortedKeys = SplayTreeSet.of(ctx.keys);
    return Hash.all([
      argID.hashCode,
      body.hashCode,
      ...sortedKeys.map((k) => k.hashCode),
      ...sortedKeys.map((k) => ctx.get(k)!.hashCode)
    ]);
  }
}

sealed class TypeValue {
  const TypeValue();
}

class TypeType extends TypeValue {
  const TypeType._();
}

const type = TypeType._();

class FnTypeType extends TypeValue {
  final TypeValue argType;
  final TypeValue returnType;

  const FnTypeType(this.argType, this.returnType);
}

const EvalCtx coreEvalCtx = IDMap({typeID: type});

Object eval(EvalCtx ctx, Expr expr) {
  switch (expr) {
    case Var():
      return ctx.get(expr.id) ?? (throw Exception('$ctx: ${expr.id}'));
    case App():
      final fn = eval(ctx, expr.fn);
      final arg = eval(ctx, expr.arg);
      return switch (fn) {
        Closure(:var argID, :var ctx, :var body) =>
          eval(argID != null ? ctx.add(argID, arg) : ctx, body),
        Object Function(EvalCtx, Object) dartFn => dartFn(ctx, arg),
        _ => throw Exception('unknown fn object, type: ${fn.runtimeType}, value: $fn'),
      };
    case Fn(kind: Fn.Def):
      return Closure(
        ctx.restrict(expr.result.freeVars.difference({expr.argID})),
        expr.argID,
        expr.result,
      );
    case Fn(kind: Fn.Typ):
      final argType = eval(ctx, expr.argType) as TypeValue;
      return FnTypeType(
        argType,
        eval(expr.argID != null ? ctx.add(expr.argID!, argType) : ctx, expr.result) as TypeValue,
      );
  }
}
