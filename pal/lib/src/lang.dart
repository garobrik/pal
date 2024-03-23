// ignore_for_file: constant_identifier_names

import 'dart:collection';

import 'serialize.dart';

typedef Program = List<List<Binding>>;

typedef ID = String;

extension IDExtension on ID {
  ID get freshen => this.replaceFirstMapped(
        RegExp('[0-9]*\$'),
        (match) => ((int.tryParse(match[0]!) ?? 0) + 1).toString(),
      );
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

  Set<ID> get freeVars => switch (this) {
        Var(:var id) => {id},
        Fn(:var argID, :var result, :var argType) =>
          result.freeVars.difference({argID}).union(argType.freeVars),
        App(:var fn, :var arg) => fn.freeVars.union(arg.freeVars),
      };

  Expr substExpr(ID from, Expr to) {
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
        var newArgID = argID;

        while (to.freeVars.contains(newArgID)) {
          newArgID = newArgID.freshen;
        }

        if (argID != newArgID) result = result.substExpr(argID, Var(newArgID));

        return Fn(
            implicit, kind, newArgID, argType.substExpr(from, to), result.substExpr(from, to));
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
  final Expr fn;
  final Expr arg;

  const App(this.implicit, this.fn, this.arg, {super.t});
}

enum FnKind { Def, Typ }

class Fn<T extends Object> extends Expr<T> {
  static const Def = FnKind.Def;
  static const Typ = FnKind.Typ;

  final FnKind kind;
  final bool implicit;
  final ID? argID;
  final Expr argType;
  final Expr result;

  const Fn(this.implicit, this.kind, this.argID, this.argType, this.result, {super.t});
}

const _typeID = 'Type';
const Type = Var(_typeID);

// Type Checking

sealed class Result<T> {
  const Result();

  bool get isFailure => switch (this) {
        Failure() => true,
        Success() => false,
      };

  T? get success => this is Success<T> ? (this as Success<T>).result : null;

  Result<R> map<R>(R Function(T) f) => switch (this) {
        Success(:var result) => Success(f(result)),
        Failure(:var msg) => Failure(msg),
      };

  Result<T> wrap(String ctx) => switch (this) {
        Failure(:var msg) => Failure(msg.wrap(ctx)),
        _ => this,
      };

  Result<T2> castFailure<T2>() => switch (this) {
        Failure(:var msg) => Failure(msg),
        _ => throw Exception(),
      };
}

class Success<T> extends Result<T> {
  final T result;

  const Success(this.result);

  @override
  String toString() => 'Success($result)';
}

class Failure<T> extends Result<T> {
  final String msg;

  const Failure(this.msg);

  @override
  String toString() => 'Failure($msg)';

  Failure<T2> cast<T2>() => Failure(msg);
}

extension IDMapOps<T> on Map<ID, T> {
  T? get(ID key) => this[key];
  Map<ID, T> add(ID key, T value) => {...this, key: value};
  Map<ID, T> union(Map<ID, T> other) => {...this, ...other};
  Map<ID, T> without(ID key) {
    final map = {...this};
    map.remove(key);
    return map;
  }

  bool equals(Map<ID, T> other) {
    if (length != other.length) return false;
    for (final MapEntry(:key, :value) in entries) {
      if (other.get(key) != value) return false;
    }
    return true;
  }

  EvalCtx restrict(Iterable<ID> ids) => {
        for (final id in ids)
          if (this.containsKey(id)) id: this.get(id)
      };
}

typedef TypeCtx = Map<ID, (Expr?, Expr?)>;
typedef EvalCtx = Map<ID, Object?>;

Result<(TypeCtx, Expr, Expr)> check(TypeCtx ctx, Expr? expectedType, Expr expr) {
  late final Expr actualType;
  late final Expr redex;

  switch (expr) {
    case Var expr:
      final bound = ctx.get(expr.id);
      if (bound == null) return Failure('unknown var $expr in ctx:\n  $ctx');
      if (bound.$1 == null && expectedType != null) {
        ctx = ctx.add(expr.id, (expectedType, bound.$2));
        actualType = expectedType;
      } else if (bound.$1 != null) {
        actualType = bound.$1!;
      } else {
        return Failure('unknown var type for $expr');
      }
      final (_, boundRedex) = bound;
      redex = boundRedex ?? expr;

    case App expr:
      final argResult = check(ctx, null, expr.arg);
      if (argResult.isFailure) return argResult.wrap('arg of $expr');
      final (argCtx, argType, argRedex) = argResult.success!;
      ctx = argCtx;

      final fnResult = check(
        ctx,
        null,
        expr.fn,
      );
      if (fnResult.isFailure) return fnResult.wrap('fn of $expr');
      final (fnCtx, fnType, fnRedex) = fnResult.success!;
      ctx = fnCtx;

      switch (fnType) {
        case Fn(
            :var implicit,
            kind: Fn.Typ,
            :var argID,
            argType: var fnArgType,
            result: var retType
          ):
          final assignableResult = assignable(ctx, fnArgType, argType);
          if (assignableResult.isFailure) {
            return assignableResult.wrap('checking passed arg in fnapp:\n$expr').castFailure();
          }
          actualType = argID != null ? retType.substExpr(argID, argRedex) : retType;
          redex = switch (fnRedex) {
            Fn(kind: Fn.Def, :var argID, result: var body) =>
              argID != null ? body.substExpr(argID, argRedex) : body,
            _ => App(implicit, fnRedex, argRedex),
          };
        case _:
          return Failure('tried to apply non fn ${expr.fn} of type $fnType');
      }

    case Fn expr:
      final argResult = check(ctx, Type, expr.argType);
      if (argResult.isFailure) return argResult.wrap('arg type of $expr');
      final (argCtx, _, argRedex) = argResult.success!;
      ctx = argCtx;

      if (ctx.containsKey(expr.argID)) {
        return Failure('shadowed variable ${expr.argID}');
      }
      final retResult = check(
        expr.argID != null ? ctx.add(expr.argID!, (argRedex, null)) : ctx,
        expr.kind == Fn.Typ ? Type : null,
        expr.result,
      );
      if (retResult.isFailure) return retResult.wrap('return type of $expr');
      final (retCtx, retType, retRedex) = retResult.success!;

      final oldArgBinding = expr.argID == null ? null : ctx.get(expr.argID!);
      ctx = retCtx;
      if (expr.argID != null) {
        ctx = ctx.without(expr.argID!);
        if (oldArgBinding != null) ctx = ctx.add(expr.argID!, oldArgBinding);
      }

      actualType =
          expr.kind == Fn.Typ ? Type : Fn(expr.implicit, Fn.Typ, expr.argID, argRedex, retType);
      redex = Fn(expr.implicit, expr.kind, expr.argID, argRedex, retRedex);
  }

  if (expectedType != null) {
    final assignableResult = assignable(ctx, reduce(ctx, expectedType), reduce(ctx, actualType))
        .wrap('checking expected type in:\n$expr');
    if (assignableResult.isFailure) return (assignableResult as Failure).cast();
    ctx = assignableResult.success!;
  }
  return Success((ctx, reduce(ctx, actualType), reduce(ctx, redex)));
}

Expr reduce(TypeCtx ctx, Expr a) => switch (a) {
      Var a =>
        ctx.get(a.id)?.$2 == null || ctx.get(a.id)?.$2 == a ? a : reduce(ctx, ctx.get(a.id)!.$2!),
      App a => switch (reduce(ctx, a.fn)) {
          Fn(kind: Fn.Def, :var argID, result: var body) =>
            reduce(ctx, argID != null ? body.substExpr(argID, reduce(ctx, a.arg)) : body),
          var fn => App(a.implicit, fn, reduce(ctx, a.arg)),
        },
      Fn a => Fn(a.implicit, a.kind, a.argID, reduce(ctx, a.argType), reduce(ctx, a.result)),
    };

Result<TypeCtx> assignable(TypeCtx ctx, Expr a, Expr b) {
  if (a.alphaEquiv(b)) return Success(ctx);
  switch ((a, b)) {
    case (Type, _):
      return Success(ctx);
    case (Fn a, Fn b) when a.kind == Fn.Typ && b.kind == Fn.Typ:
      final argCtx = assignable(ctx, b.argType, a.argType).wrap('''
args of:
${a.toString().indent}
${b.toString().indent}''');
      if (argCtx.isFailure) return argCtx;
      final retCtx = assignable(argCtx.success!, a.result, b.result).wrap('''
return types of:
${a.toString().indent}
${b.toString().indent}''');
      return retCtx.map((ctx) => a.argID == null ? ctx : ctx.without(a.argID!));
    case (Var a, Expr b):
      if (ctx.get(a.id) == null || ctx.get(a.id)!.$2 == null) {
        return Success(ctx.add(a.id, (Type, b)));
      } else {
        return assignable(ctx, ctx.get(a.id)!.$2!, b);
      }
    case (App a, App b):
      final fnCtx = assignable(ctx, a.fn, b.fn).wrap('''
fns of:
${a.toString().indent}
${b.toString().indent}''');
      if (fnCtx.isFailure) return fnCtx;
      return assignable(fnCtx.success!, a.arg, b.arg);
    case _:
      return Failure('not assignable:\n  $a\n  $b');
  }
}

// Evaluation

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

final EvalCtx coreEvalCtx = {Type.id: type};
final TypeCtx coreTypeCtx = {Type.id: (Type, Type)};

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
        ctx.restrict((expr.result).freeVars.difference({expr.argID})),
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

extension on String {
  String get indent => splitMapJoin('\n', onNonMatch: (s) => '  $s');
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
