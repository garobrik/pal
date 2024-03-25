// ignore_for_file: constant_identifier_names

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

  @override
  bool operator ==(Object other) => other is Expr && this.alphaEquiv(other);

  int _hashCode(List<String?> ctx) => switch (this) {
        Hole() => 0,
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

class Hole<T extends Object> extends Expr<T> {
  const Hole({super.t});
}

const hole = Hole();

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
        Hole() => {},
        Var(:var id) => {id},
        Fn(:var argID, :var result, :var argType) =>
          result.freeVars.difference({argID}).union(argType.freeVars),
        App(:var fn, :var arg) => fn.freeVars.union(arg.freeVars),
      };

  Expr<T> substExpr(ID from, Expr<T> to) {
    switch (this) {
      case Hole():
        return this;
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

  bool get complete => switch (this) {
        Hole() => false,
        Var() => true,
        App a => a.fn.complete && a.arg.complete,
        Fn f => f.argType.complete && f.result.complete,
      };
}

const typeID = 'Type';
const Type = Var(typeID);
const TypeCtx coreTypeCtx = IDMap({typeID: (Type, Type)});

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
}

typedef TypeCtx<T extends Object> = IDMap<(Expr<T>, Expr<T>)>;

sealed class Result<T> {
  const Result();
}

class Progress<T> extends Result<T> {
  final T result;
  final TypeCtx inferences;

  const Progress(this.result, [this.inferences = const IDMap({})]);

  @override
  String toString() => '$result, $inferences';
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

typedef CheckResult = Result<(Expr, Expr)>;
typedef CheckProgress = Progress<(Expr, Expr)>;
typedef CheckFailure = Failure<(Expr, Expr)>;

CheckResult check(TypeCtx ctx, Expr expectedType, Expr expr) {
  final progress = _check(ctx, expectedType, expr);
  if (progress is CheckProgress) {
    assert(progress.result.$1.complete);
  }
  return progress;
}

CheckResult _check(TypeCtx ctx, Expr expectedType, Expr expr) {
  CheckResult subCheck(TypeCtx ctx, Expr expr) {
    if (expr is Hole) {
      return const Progress((hole, hole));
    } else if (expr is Var) {
      final bound = ctx.get(expr.id);
      if (bound == null) return Failure('unknown var $expr in ctx:\n  $ctx');
      final (type, redex) = bound;
      if (type is Hole && expectedType is! Hole) {
        final newBinding = (expectedType, redex is Hole ? expr : redex);
        return Progress(
          (newBinding.$1, newBinding.$2),
          IDMap({expr.id: newBinding}),
        );
      } else if (type is! Hole) {
        return Progress((type, redex is Hole ? expr : redex));
      } else {
        return const Progress((hole, hole));
      }
    } else if (expr is App) {
      Expr fnType = const Fn.typ(false, null, hole, hole);
      Expr fnRedex = expr.fn;
      TypeCtx inferences = const IDMap({});
      // TODO: persist partial state across loops?
      // TODO: force two loop iterations to get argType?
      // TODO: implicit? argID?
      final fnResult = _check(ctx, Fn.typ(false, null, hole, expectedType), expr.fn);
      if (fnResult is CheckFailure) return fnResult.wrap('fn of $expr');
      if (fnResult is! CheckProgress) throw Exception();
      inferences = inferences.union(fnResult.inferences);
      ctx = ctx.union(fnResult.inferences);

      (fnType, fnRedex) = fnResult.result;
      if (fnType is! Fn && fnType is! Hole) {
        return Failure(
          'expected type of fn applied at ${expr.t} to be function type!\nexpression:\n${expr.fn.toString().indent}\nactualType:${fnType.toString().indent}',
        );
      }

      final argResult = _check(ctx, fnType is Fn ? fnType.argType : hole, expr.arg);
      if (argResult is CheckFailure) return argResult.wrap('arg of $expr');
      if (argResult is! CheckProgress) throw Exception();

      inferences = inferences.union(argResult.inferences);
      ctx = ctx.union(argResult.inferences);

      final (_, argRedex) = argResult.result;

      Expr doSubst(Expr fn, Expr def) => fn is Fn
          ? fn.argID != null
              ? fn.result.substExpr(fn.argID!, argRedex)
              : fn.result
          : def;

      return Progress(
        (
          doSubst(fnType, hole),
          doSubst(fnRedex, App(expr.implicit, fnRedex, argRedex)),
        ),
        inferences,
      );
    } else if (expr case Fn(:var argID)) {
      if (argID != null && ctx.containsKey(argID)) {
        return Failure('shadowed variable ${expr.argID}');
      }

      TypeCtx inferences = const IDMap({});

      final argResult = _check(ctx, Type, expr.argType);

      if (argResult is CheckFailure) return argResult.wrap('arg type of $expr');
      if (argResult is! CheckProgress) throw Exception();
      inferences = inferences.union(argResult.inferences);
      ctx = ctx.union(argResult.inferences);

      var (_, argTypeRedex) = argResult.result;

      final retResult = _check(
        // TODO: fill in redex somehow?
        argID != null ? ctx.add(argID, (argTypeRedex, hole)) : ctx,
        // TODO: use expectedType to enforce retResult type
        expr.kind == Fn.Typ ? Type : hole,
        expr.result,
      );
      if (retResult is CheckFailure) return retResult.wrap('arg type of $expr');
      if (retResult is! CheckProgress) throw Exception();
      inferences = inferences.union(retResult.inferences);
      final (retType, retRedex) = retResult.result;

      if (argID != null) {
        argTypeRedex = inferences.get(argID)?.$1 ?? argTypeRedex;
        inferences = inferences.without(argID);
      }

      return Progress(
        (
          expr.kind == Fn.Typ ? Type : Fn(expr.implicit, Fn.Typ, expr.argID, argTypeRedex, retType),
          Fn(expr.implicit, expr.kind, expr.argID, argTypeRedex, retRedex),
        ),
        argID != null ? inferences.without(argID) : inferences,
      );
    } else {
      throw Exception('unexpected case ${expr.runtimeType}');
    }
  }

  bool gotMore = true;
  TypeCtx inferences = const IDMap({});
  Expr resultType = hole;
  while (gotMore && !resultType.complete) {
    gotMore = false;

    final result = subCheck(ctx, expr);

    if (result is CheckFailure) return result.wrap();
    if (result is! CheckProgress) throw Exception();
    if (!result.inferences.isEmpty) gotMore = true;
    inferences = result.inferences;
    ctx = ctx.union(result.inferences);

    (resultType, expr) = result.result;

    if (expectedType is! Hole) {
      final result = unify(ctx, reduce(ctx, expectedType), reduce(ctx, resultType));

      if (result is AssgnFailure) {
        return Failure(result.reason.wrap('checking expected type in:\n$expr'));
      }
      if (result is! AssgnProgress) throw Exception();
      if (!result.inferences.isEmpty) gotMore = true;
      inferences = inferences.union(result.inferences);
      ctx = ctx.union(result.inferences);
    }
  }

  return Progress((reduce(ctx, resultType), reduce(ctx, expr)), inferences);
}

typedef AssgnResult = Result<void>;
typedef AssgnProgress = Progress<void>;
typedef AssgnFailure = Failure<void>;

AssgnResult unify(TypeCtx ctx, Expr a, Expr b) {
  if (a.alphaEquiv(b)) return const Progress(null);
  switch ((a, b)) {
    case (Type, _):
      return const Progress(null);
    case (_, Type):
      return const Progress(null);
    case (Hole _, _):
      return const Progress(null);
    case (_, Hole _):
      return const Progress(null);
    case (Fn a, Fn b) when a.kind == Fn.Typ && b.kind == Fn.Typ:
      final argCtx = unify(ctx, a.argType, b.argType);
      if (argCtx is AssgnFailure) {
        return argCtx.wrap('''
args of:
${a.toString().indent}
${b.toString().indent}''');
      }
      if (argCtx is! Progress) throw Exception();
      final retCtx = unify(ctx.union(argCtx.inferences), a.result, b.result);

      if (retCtx is AssgnFailure) {
        return retCtx.wrap('''
return types of:
${a.toString().indent}
${b.toString().indent}''');
      }
      if (retCtx is! Progress) throw Exception();

      return Progress(
        null,
        argCtx.inferences.union(
          a.argID == null ? retCtx.inferences : retCtx.inferences.without(a.argID!),
        ),
      );
    case (Var a, Expr b):
      if (ctx.get(a.id) == null || ctx.get(a.id)!.$2 is Hole) {
        return Progress(null, IDMap({a.id: (Type, b)}));
      } else {
        return unify(ctx, ctx.get(a.id)!.$2, b);
      }
    case (App a, App b):
      final fnCtx = unify(ctx, a.fn, b.fn);

      if (fnCtx is AssgnFailure) {
        return fnCtx.wrap('''
fns of:
${a.fn.toString().indent}
${b.fn.toString().indent}''');
      }
      if (fnCtx is! Progress) throw Exception();

      final argCtx = unify(ctx.union(fnCtx.inferences), a.arg, b.arg);

      if (argCtx is AssgnFailure) {
        return argCtx.wrap('''
args of:
${a.fn.toString().indent}
${b.fn.toString().indent}''');
      }
      if (argCtx is! Progress) throw Exception();

      return Progress(null, fnCtx.inferences.union(argCtx.inferences));
    case _:
      return Failure('can\'t unify:\n  $a\n  $b');
  }
}

Expr reduce(TypeCtx ctx, Expr a) => switch (a) {
      Hole() => a,
      Var a => switch (ctx.get(a.id)) {
          (_, var redex) when redex is! Hole && redex != a => reduce(ctx, redex),
          _ => a,
        },
      App a => switch (reduce(ctx, a.fn)) {
          Fn(kind: Fn.Def, :var argID, result: var body) =>
            reduce(ctx, argID != null ? body.substExpr(argID, reduce(ctx, a.arg)) : body),
          var fn => App(a.implicit, fn, reduce(ctx, a.arg)),
        },
      Fn a => Fn(a.implicit, a.kind, a.argID, reduce(ctx, a.argType), reduce(ctx, a.result)),
    };

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
