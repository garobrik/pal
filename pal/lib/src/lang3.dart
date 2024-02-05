// ignore_for_file: constant_identifier_names

import 'dart:collection';

typedef ID = String;

extension IDExtension on ID {
  ID get freshen => this.replaceFirstMapped(
        RegExp('[0-9]*\$'),
        (match) => ((int.tryParse(match[0]!) ?? 0) + 1).toString(),
      );
}

sealed class Expr {
  const Expr();

  @override
  String toString() {
    return toStringIndent(100, 100).join('\n');
  }

  List<String> toStringIndent(int spaceOnNewLine, int remainingLine) {
    switch (this) {
      case Var(:var id):
        return [id];
      case FnApp(:var fn, :var arg):
        final fnString = fn.toStringIndent(spaceOnNewLine, remainingLine);
        final argRemainingLine = remainingLine - fnString.last.length - 2;
        final argString = arg.toStringIndent(spaceOnNewLine - 2, argRemainingLine);
        final fits = argString.first.length <= argRemainingLine;
        final fitsOne = fits && argString.length == 1;
        final fitsNew = argString.map((s) => s.trim().length).sum() <= spaceOnNewLine - 2;
        return [
          ...fnString.sublist(0, fnString.length - 1),
          if (fitsOne)
            '${fnString.last}(${argString.first})'
          else if (fitsNew) ...[
            '${fnString.last}(',
            '  ${argString.map((s) => s.trim()).join()}',
            ')'
          ] else if (fits) ...[
            '${fnString.last}(${argString.first}',
            ...argString.sublist(1, argString.length - 1),
            if (argString.last == ')') '))' else ...[argString.last, ')']
          ] else ...[
            '${fnString.last}(',
            ...argString.map((s) => '  $s'),
            ')'
          ]
        ];
      case FnDef(:var argID, :var argType, :var body):
        argID = argID ?? '_';
        final argPart = '$argID:  ->'.length;
        final argTypeString = argType.toStringIndent(spaceOnNewLine - 2, remainingLine - argPart);
        final typeFits = argTypeString.length == 1 && argTypeString.first.length <= remainingLine;
        final argPartString = [
          if (typeFits)
            '$argID: ${argTypeString.first} ->'
          else ...[
            '$argID:',
            ...argTypeString.sublist(0, argTypeString.length - 1).map((s) => '  $s'),
            '  ${argTypeString.last} ->'
          ]
        ];
        final bodyRemainingLine = remainingLine - argPartString.last.length - 1;
        final bodyString = body.toStringIndent(spaceOnNewLine - 2, bodyRemainingLine);
        final fits = bodyString.first.length <= bodyRemainingLine;
        return [
          ...argPartString.sublist(0, argPartString.length - 1),
          if (fits) ...[
            '${argPartString.last} ${bodyString.first}',
            ...bodyString.sublist(1)
          ] else ...[
            argPartString.last,
            '  ${bodyString.first}',
            ...bodyString.sublist(1).map((s) => '  $s')
          ],
        ];
      case FnType(:var argID, :var argType, :var retType):
        var argPart = (argID == null ? ' =>' : '$argID:  =>').length;
        if (argType is FnType) argPart += 2;
        var argTypeString = argType.toStringIndent(spaceOnNewLine - 2, remainingLine - argPart);
        if (argType is FnType) {
          argTypeString = ['(${argTypeString.first}', ...argTypeString.skip(1)];
          argTypeString = [
            ...argTypeString.take(argTypeString.length - 1),
            '${argTypeString.last})'
          ];
        }
        final typeFits = argTypeString.length == 1 && argTypeString.first.length <= remainingLine;
        argID = argID == null ? '' : '$argID: ';
        final argPartString = [
          if (typeFits)
            '$argID${argTypeString.first} =>'
          else ...[
            argID.trim(),
            ...argTypeString.sublist(0, argTypeString.length - 1).map((s) => '  $s'),
            '  ${argTypeString.last} =>'
          ]
        ];
        final retTypeRemainingLine = remainingLine - argPartString.last.length - 1;
        final retTypeString = retType.toStringIndent(spaceOnNewLine - 2, retTypeRemainingLine);
        final fits = retTypeString.first.length <= retTypeRemainingLine;
        return [
          ...argPartString.sublist(0, argPartString.length - 1),
          if (fits) ...[
            '${argPartString.last} ${retTypeString.first}',
            ...retTypeString.sublist(1)
          ] else ...[
            argPartString.last,
            '  ${retTypeString.first}',
            ...retTypeString.sublist(1).map((s) => '  $s')
          ],
        ];
    }
  }

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
          fn: FnApp(fn: FnApp(fn: Var(id: _fnDefID), arg: Var(id: var argID)), arg: var argType),
          arg: var body
        ) =>
          (FnDef(argID == '_' ? null : argID, argType, body), restRest),
        FnApp(
          fn: FnApp(fn: FnApp(fn: Var(id: _fnTypeID), arg: Var(id: var argID)), arg: var argType),
          arg: var retType
        ) =>
          (FnType(argID == '_' ? null : argID, argType, retType), restRest),
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
        FnDef(:var argID, :var body, :var argType) =>
          body.freeVars.difference({argID}).union(argType.freeVars),
        FnType(:var argID, :var retType, :var argType) =>
          retType.freeVars.difference({argID}).union(argType.freeVars),
        FnApp(:var fn, :var arg) => fn.freeVars.union(arg.freeVars),
      };

  Expr substExpr(ID from, Expr to) {
    switch (this) {
      case Var(:var id):
        return id == from ? to : this;
      case FnApp(:var fn, :var arg):
        return FnApp(fn.substExpr(from, to), arg.substExpr(from, to));
      case FnType(:var argID, :var argType, :var retType):
        final origRetType = retType;
        final origArgID = argID;

        while (to.freeVars.contains(argID)) {
          argID = argID!.freshen;
        }

        if (argID != origArgID) retType = retType.substExpr(origArgID!, Var(argID!));

        return FnType(
          origArgID == from ? origArgID : argID,
          argType.substExpr(from, to),
          origArgID == from ? origRetType : retType.substExpr(from, to),
        );
      case FnDef(:var argID, :var argType, :var body):
        final origBody = body;
        final origArgID = argID;

        while (to.freeVars.contains(argID)) {
          argID = argID!.freshen;
        }

        if (argID != origArgID) body = body.substExpr(origArgID!, Var(argID!));

        return FnDef(
          origArgID == from ? origArgID : argID,
          argType.substExpr(from, to),
          origArgID == from ? origBody : body.substExpr(from, to),
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Expr &&
      switch ((this, other)) {
        (Var thisV, Var other) => thisV.id == other.id,
        (FnApp thisF, FnApp other) => thisF.arg == other.arg && thisF.fn == other.fn,
        (FnDef thisD, FnDef other) =>
          thisD.argID == other.argID && thisD.argType == other.argType && thisD.body == other.body,
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
        FnDef d => Hash.all([d.argID, d.argType, d.body]),
      };
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
  final ID? argID;
  final Expr argType;
  final Expr body;

  const FnDef(this.argID, this.argType, this.body);
}

class FnType extends Expr {
  final ID? argID;
  final Expr argType;
  final Expr retType;

  const FnType(this.argID, this.argType, this.retType);
}

const _typeID = 'Type';
const Type = Var(_typeID);
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
          if (this.containsKey(id)) id: this.get(id)!
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

    case FnApp expr:
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
        case FnType(:var argID, argType: var fnArgType, :var retType):
          final assignableResult = assignable(ctx, fnArgType, argType);
          if (assignableResult.isFailure) {
            return assignableResult.wrap('checking passed arg in fnapp $expr').castFailure();
          }
          actualType = argID != null ? retType.substExpr(argID, argRedex) : retType;
          redex = switch (fnRedex) {
            FnDef(:var argID, :var body) => argID != null ? body.substExpr(argID, argRedex) : body,
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

      if (ctx.containsKey(expr.argID)) {
        return Failure('shadowed variable ${expr.argID}');
      }
      final retResult = check(
        expr.argID != null ? ctx.add(expr.argID!, (argRedex, null)) : ctx,
        Type,
        expr.retType,
      );
      if (retResult.isFailure) return retResult.wrap('return type of $expr');
      final (retCtx, _, retRedex) = retResult.success!;

      final oldArgBinding = expr.argID == null ? null : ctx.get(expr.argID!);
      ctx = retCtx;
      if (expr.argID != null) {
        ctx = ctx.without(expr.argID!);
        if (oldArgBinding != null) ctx = ctx.add(expr.argID!, oldArgBinding);
      }

      actualType = Type;
      redex = FnType(expr.argID, argRedex, retRedex);

    case FnDef expr:
      final argResult = check(ctx, Type, expr.argType);
      if (argResult.isFailure) return argResult.wrap('arg type of $expr');
      final (argCtx, _, argRedex) = argResult.success!;
      ctx = argCtx;

      if (ctx.containsKey(expr.argID)) {
        return Failure('shadowed variable ${expr.argID}');
      }
      final bodyResult = check(
        expr.argID != null ? ctx.add(expr.argID!, (argRedex, null)) : ctx,
        null,
        expr.body,
      );
      if (bodyResult.isFailure) return bodyResult.wrap('body of $expr');
      final (bodyCtx, bodyType, bodyRedex) = bodyResult.success!;

      final oldArgBinding = expr.argID == null ? null : ctx.get(expr.argID!);
      ctx = bodyCtx;
      if (expr.argID != null) {
        ctx = ctx.without(expr.argID!);
        if (oldArgBinding != null) ctx = ctx.add(expr.argID!, oldArgBinding);
      }

      actualType = FnType(expr.argID, argRedex, bodyType);
      redex = FnDef(expr.argID, argRedex, bodyRedex);
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
      FnApp a => switch (reduce(ctx, a.fn)) {
          FnDef(:var argID, :var body) =>
            reduce(ctx, argID != null ? body.substExpr(argID, a.arg) : body),
          var fn => FnApp(fn, reduce(ctx, a.arg)),
        },
      FnType a => FnType(a.argID, reduce(ctx, a.argType), reduce(ctx, a.retType)),
      FnDef a => FnDef(a.argID, reduce(ctx, a.argType), reduce(ctx, a.body)),
    };

Result<TypeCtx> assignable(TypeCtx ctx, Expr a, Expr b) {
  if (a == b) return Success(ctx);
  switch ((a, b)) {
    case (Type, _):
      return Success(ctx);
    case (FnType a, FnType b):
      final argCtx = assignable(ctx, b.argType, a.argType).wrap('''
        args of:
          $a
          $b
      ''');
      if (argCtx.isFailure) return argCtx;
      final retCtx = assignable(argCtx.success!, a.retType, b.retType).wrap('''
        return types of:
          $a
          $b
      ''');
      return retCtx.map((ctx) => a.argID == null ? ctx : ctx.without(a.argID!));
    case (Var a, Expr b):
      if (ctx.get(a.id) == null) {
        return Success(ctx.add(a.id, (Type, b)));
      } else if (ctx.get(a.id)!.$2 == null) {
        return Success(ctx.add(a.id, (Type, b)));
      } else {
        return assignable(ctx, ctx.get(a.id)!.$2!, b);
      }
    case (FnApp a, FnApp b):
      final fnCtx = assignable(ctx, a.fn, b.fn).wrap('''
        fns of:
          $a
          $b 
      ''');
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
      other is Closure && argID == other.argID && body == other.body && ctx.equals(other.ctx);

  @override
  int get hashCode {
    final sortedKeys = SplayTreeSet.of(ctx.keys);
    return Hash.all([argID, body, ...sortedKeys, ...sortedKeys.map((k) => ctx.get(k)!)]);
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
    case Var expr:
      return ctx.get(expr.id) ?? (throw Exception('$ctx: ${expr.id}'));
    case FnApp expr:
      final fn = eval(ctx, expr.fn);
      final arg = eval(ctx, expr.arg);
      return switch (fn) {
        Closure(:var argID, :var ctx, :var body) =>
          eval(argID != null ? ctx.add(argID, arg) : ctx, body),
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
      final argType = eval(ctx, expr.argType) as TypeValue;
      return FnTypeType(
        argType,
        eval(expr.argID != null ? ctx.add(expr.argID!, argType) : ctx, expr.retType) as TypeValue,
      );
  }
}

extension on String {
  String get indent => splitMapJoin('\n', onNonMatch: (s) => '  $s');
  String wrap(String ctx) => ctx.isEmpty ? this : '$ctx\n$indent';
  String get last => this[this.length - 1];
  String get rest => this.substring(0, this.length - 1);
}

extension on Iterable<int> {
  int sum() => this.reduce((a, b) => a + b);
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

  static int all(List<Object?> objects) => finish(objects.map((o) => o.hashCode).fold(0, combine));
}
