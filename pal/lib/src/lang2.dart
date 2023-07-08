// ignore_for_file: constant_identifier_names

import 'dart:collection';

typedef ID = String;

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

  static int all(List<Object> objects) => finish(objects.map((o) => o.hashCode).fold(0, combine));
}

sealed class Expr {
  const Expr();

  @override
  String toString() => switch (this) {
        Var(:var id) => id,
        FnApp(:var fn, :var arg) => '$fn($arg)',
        FnDef(:var argID, :var argType, :var retType, :var body) =>
          'FnDef($argID)($argType)($retType)($body)',
        FnType(:var argID, :var argType, :var retType) => 'FnType($argID)($argType)($retType)'
      };

  static (Expr, String) parse(String s) {
    s = s.trim();
    if (s.last == ')') {
      var (expr, rest) = parse(s.rest);
      assert(rest.last == '(', s);
      rest = rest.rest;
      if (rest.isEmpty) return (expr, rest.rest);
      assert(rest.last.trim().isNotEmpty);
      var (fn, restRest) = parse(rest);
      return switch (FnApp(fn, expr)) {
        FnApp(
          fn: FnApp(
            fn: FnApp(fn: FnApp(fn: Var(id: _fnDefID), arg: Var(id: var argID)), arg: var argType),
            arg: var retType
          ),
          arg: var body
        ) =>
          (FnDef(argID, argType, retType, body), restRest),
        FnApp(
          fn: FnApp(fn: FnApp(fn: Var(id: _fnTypeID), arg: Var(id: var argID)), arg: var argType),
          arg: var retType
        ) =>
          (FnType(argID, argType, retType), restRest),
        var expr => (expr, restRest)
      };
    } else {
      assert(s.last != '(', s);
      final idStart = s.lastIndexOf(RegExp(r'[() \n]')) + 1;
      return (Var(s.substring(idStart)), s.substring(0, idStart).trim());
    }
  }

  Set<ID> get freeVars => switch (this) {
        Var(:var id) => {id},
        FnDef(:var argID, :var retType, :var body) =>
          retType.freeVars.union(body.freeVars).difference({argID}),
        FnType(:var argID, :var retType) => retType.freeVars.difference({argID}),
        FnApp(:var fn, :var arg) => fn.freeVars.union(arg.freeVars),
      };

  Expr substVar(ID from, ID to) => switch (this) {
        Var(:var id) => id == from ? Var(to) : this,
        FnApp(:var fn, :var arg) => FnApp(fn.substVar(from, to), arg.substVar(from, to)),
        FnType(:var argID, :var argType, :var retType) => FnType(argID, argType.substVar(from, to),
            argID == from ? retType : retType.substVar(from, to)),
        FnDef(:var argID, :var argType, :var retType, :var body) => FnDef(
            argID,
            argType.substVar(from, to),
            argID == from ? retType : retType.substVar(from, to),
            argID == from ? body : body.substVar(from, to)),
      };

  Expr substExpr(ID from, Expr to) => switch (this) {
        Var(:var id) => id == from ? to : this,
        FnApp(:var fn, :var arg) => FnApp(fn.substExpr(from, to), arg.substExpr(from, to)),
        FnType(:var argID, :var argType, :var retType) => FnType(argID, argType.substExpr(from, to),
            argID == from ? retType : retType.substExpr(from, to)),
        FnDef(:var argID, :var argType, :var retType, :var body) => FnDef(
            argID,
            argType.substExpr(from, to),
            argID == from ? retType : retType.substExpr(from, to),
            argID == from ? body : body.substExpr(from, to)),
      };

  @override
  bool operator ==(Object other) =>
      other is Expr &&
      switch ((this, other)) {
        (Var thisV, Var other) => thisV.id == other.id,
        (FnApp thisF, FnApp other) => thisF.arg == other.arg && thisF.fn == other.fn,
        (FnDef thisD, FnDef other) => thisD.argID == other.argID &&
            thisD.argType == other.argType &&
            thisD.retType == other.retType &&
            thisD.body == other.body,
        (FnType thisT, FnType other) => thisT.argID == other.argID &&
            thisT.argType == other.argType &&
            thisT.retType == other.retType,
        _ => false,
      };

  @override
  int get hashCode => switch (this) {
        Var v => Hash.all([v.id]),
        FnApp fn => Hash.all([fn.fn, fn.arg]),
        FnType t => Hash.all([t.argID, t.argType, t.retType]),
        FnDef d => Hash.all([d.argID, d.argType, d.retType, d.body]),
      };
}

extension on String {
  String get last => this[this.length - 1];
  String get rest => this.substring(0, this.length - 1);
}

class Var extends Expr {
  final ID id;

  const Var(this.id);
}

class FnApp extends Expr {
  final Expr fn;
  final Expr arg;

  const FnApp(this.fn, this.arg);
}

class FnDef extends Expr {
  final ID argID;
  final Expr argType;
  final Expr retType;
  final Expr body;

  const FnDef(this.argID, this.argType, this.retType, this.body);
}

class FnType extends Expr {
  final ID argID;
  final Expr argType;
  final Expr retType;

  const FnType(this.argID, this.argType, this.retType);
}

const _typeID = 'Type';
const Type = Var(_typeID);
const _inferID = '_';
const Infer = Var(_inferID);
const _fnDefID = 'FnDef';
const _fnTypeID = 'FnType';

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
}

extension on TypeCtx {
  TypeCtx add(ID key, (Expr?, Expr?) value) => {...this, key: value};
  TypeCtx without(ID key) {
    final map = {...this};
    map.remove(key);
    return map;
  }
}

typedef TypeCtx = Map<ID, (Expr?, Expr?)>;

Result<(TypeCtx, Expr, Expr)> check(TypeCtx ctx, Expr? expectedType, Expr expr) {
  late final Expr actualType;
  late final Expr redex;

  switch (expr) {
    case Var expr:
      final bound = ctx[expr.id];
      if (bound == null) return Failure('unknown var $expr');
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

    case FnApp expr:
      final argResult = check(ctx, null, expr.arg);
      if (argResult.isFailure) return argResult.wrap('arg of $expr');
      final (argCtx, argType, argRedex) = argResult.success!;
      ctx = argCtx;

      final fnResult = check(
        ctx,
        expectedType != null ? FnType('_', argType, expectedType) : null,
        expr.fn,
      );
      if (fnResult.isFailure) return fnResult.wrap('fn of $expr');
      final (fnCtx, fnType, fnRedex) = fnResult.success!;
      ctx = fnCtx;

      switch (fnType) {
        case FnType(:var argID, :var retType):
          actualType = retType.substExpr(argID, argRedex);
          redex = switch (fnRedex) {
            FnDef(:var argID, :var body) => body.substExpr(argID, argRedex),
            _ => FnApp(fnRedex, argRedex),
          };
        case _:
          return Failure('tried to apply non fn ${expr.fn} of type $fnType');
      }

    case FnType expr:
      final argResult = check(ctx, Type, expr.argType);
      if (argResult.isFailure) return argResult.wrap('arg type of $expr');
      final (argCtx, _, argRedex) = argResult.success!;
      ctx = argCtx;

      final retResult = check(ctx.add(expr.argID, (argRedex, null)), Type, expr.retType);
      if (retResult.isFailure) return retResult.wrap('return type of $expr');
      final (retCtx, _, retRedex) = retResult.success!;
      final oldArgID = ctx[expr.argID];
      ctx = retCtx.without(expr.argID);
      if (oldArgID != null) ctx = ctx.add(expr.argID, oldArgID);

      actualType = Type;
      redex = FnType(expr.argID, argRedex, retRedex);

    case FnDef expr:
      final argResult = check(ctx, Type, expr.argType);
      if (argResult.isFailure) return argResult.wrap('arg type of $expr');
      final (argCtx, _, argRedex) = argResult.success!;
      ctx = argCtx;

      final retResult = check(ctx.add(expr.argID, (argRedex, null)), Type, expr.retType);
      if (retResult.isFailure) return retResult.wrap('return type of $expr');
      final (retCtx, _, retRedex) = retResult.success!;

      final bodyResult = check(retCtx, retRedex, expr.body);
      if (bodyResult.isFailure) return bodyResult.wrap('body of $expr');
      final (bodyCtx, _, bodyRedex) = bodyResult.success!;

      final oldArgID = ctx[expr.argID];
      ctx = bodyCtx.without(expr.argID);
      if (oldArgID != null) ctx = ctx.add(expr.argID, oldArgID);

      actualType = FnType(expr.argID, argRedex, retRedex);
      redex = FnDef(expr.argID, argRedex, retRedex, bodyRedex);
  }

  return (expectedType != null
          ? assignable(ctx, expectedType, actualType).wrap('checking expected type in $expr')
          : Success(ctx))
      .map((ctx) => (ctx, actualType, reduce(ctx, redex)));
}

Expr reduce(TypeCtx ctx, Expr a) => switch (a) {
      Var a => ctx[a]?.$2 == null ? a : reduce(ctx, ctx[a]!.$2!),
      FnApp a => switch (reduce(ctx, a.fn)) {
          FnDef fn => reduce(ctx, fn.body.substExpr(fn.argID, a.arg)),
          _ => a,
        },
      _ => a
    };

Result<TypeCtx> assignable(TypeCtx ctx, Expr a, Expr b) {
  if (a == b) return Success(ctx);
  switch ((a, b)) {
    case (Infer, _):
      return Success(ctx);
    case (Type, _):
      return Success(ctx);
    case (FnType a, FnType b):
      final argCtx = assignable(ctx, b.argType, a.argType);
      if (argCtx.isFailure) return argCtx;
      return assignable(argCtx.success!, a.retType, b.retType).map((ctx) => ctx.without(b.argID));
    case (Var a, Expr b):
      if (ctx[a.id] == null) {
        return Success(ctx.add(a.id, (Type, b)));
      } else if (ctx[a.id]!.$2 == null) {
        return Success(ctx.add(a.id, (Type, b)));
      } else {
        return assignable(ctx, ctx[a.id]!.$2!, b);
      }
    case _:
      return Failure('unknown type expr $a');
  }
}

// Evaluation

typedef EvalCtx = Map<ID, Object>;

extension on EvalCtx {
  EvalCtx add(ID key, Object value) => {...this, key: value};

  bool equals(EvalCtx other) {
    if (length != other.length) return false;
    for (final MapEntry(:key, :value) in entries) {
      if (other[key] != value) return false;
    }
    return true;
  }

  EvalCtx restrict(Iterable<ID> ids) => {
        for (final id in ids)
          if (this[id] != null) id: this[id]!
      };
}

class Closure {
  final EvalCtx ctx;
  final ID argID;
  final Expr body;

  Closure(this.ctx, this.argID, this.body);

  @override
  String toString() => 'Closure($ctx, $argID, $body)';

  @override
  bool operator ==(Object other) =>
      other is Closure && argID == other.argID && body == other.body && ctx.equals(other.ctx);

  @override
  int get hashCode {
    final sortedKeys = SplayTreeSet.of(ctx.keys);
    return Hash.all([argID, body, ...sortedKeys, ...sortedKeys.map((k) => ctx[k]!)]);
  }
}

sealed class TypeValue {
  const TypeValue();
}

class TypeType {
  const TypeType._();
}

const type = TypeType._();

class FnTypeType extends TypeValue {
  final TypeValue argType;
  final TypeValue returnType;

  const FnTypeType(this.argType, this.returnType);
}

final EvalCtx defaultEvalCtx = {Type.id: type};
final TypeCtx defaultTypeCtx = {Type.id: (Type, Type)};

Object eval(EvalCtx ctx, Expr expr) {
  switch (expr) {
    case Var expr:
      return ctx[expr.id] ?? (throw Exception('$ctx: ${expr.id}'));
    case FnApp expr:
      final fn = eval(ctx, expr.fn);
      final arg = eval(ctx, expr.arg);
      return switch (fn) {
        Closure clos => eval(clos.ctx.add(clos.argID, arg), clos.body),
        Object Function(EvalCtx, Object) dartFn => dartFn(ctx, arg),
        _ => throw Exception('unknown fn object, type: ${fn.runtimeType}, value: $fn'),
      };
    case FnDef expr:
      return Closure(
        ctx.restrict((expr.body).freeVars.difference({expr.argID})),
        expr.argID,
        expr.body,
      );
    case FnType expr:
      return FnTypeType(
        eval(ctx, expr.argType) as TypeValue,
        eval(ctx, expr.retType) as TypeValue,
      );
  }
}

extension Indent on String {
  String get indent => splitMapJoin('\n', onNonMatch: (s) => '  $s');
  String wrap(String ctx) => ctx.isEmpty ? this : '$ctx:\n$indent';
}
