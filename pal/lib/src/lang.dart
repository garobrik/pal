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
        var newArgID = to.freeVars.freshen(argID);

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

extension<T extends Object> on TypeCtx<T> {
  TypeCtx<T> addAll(Iterable<ID> ids) =>
      union(IDMap({for (final id in ids) id: const Ann.empty()}));
}

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

class Ann<T extends Object> {
  final Expr<T>? type;
  final Expr<T>? value;

  const Ann(this.type, this.value);
  const Ann.empty()
      : type = null,
        value = null;

  @override
  String toString() => '${value ?? '_'}: ${type ?? '_'}';
}

class Jdg<T extends Object> {
  final Expr<T> type;
  final Expr<T> value;

  const Jdg(this.type, this.value);

  @override
  String toString() => '$value: $type';
}

typedef TypeCtx<T extends Object> = IDMap<Ann>;

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

typedef CheckResult = Result<Jdg>;
typedef CheckProgress = Progress<Jdg>;
typedef CheckFailure = Failure<Jdg>;

CheckResult check(TypeCtx ctx, Expr? expectedType, Expr expr) {
  expectedType = expectedType ?? Var([...ctx.keys, ...expr.freeVars].freshen('EXPECTED_TYPE'));
  final expectedValue = Var([...ctx.keys, ...expr.freeVars].freshen('EXPECTED_VALUE'));
  final progress = _check(ctx, expectedType, expectedValue, expr);
  if (progress case CheckProgress(result: Jdg(:var type, :var value))) {
    assert(type.freeVars.every((v) => ctx.containsKey(v)), type.toString());
    assert(value.freeVars.every((v) => ctx.containsKey(v)), value.toString());
  }
  return progress;
}

CheckResult _check(TypeCtx ctx, Expr expectedType, Expr expectedValue, Expr expr) {
  CheckResult subCheck(TypeCtx ctx, Expr expr) {
/////// Check Var
    if (expr is Var) {
      final Ann(:type, value: redex) = ctx.get(expr.id) ?? const Ann(null, null);
      if (type != null && type is! Var) {
        return Progress(Jdg(type, redex ?? expr));
      }

      return Progress(
        Jdg(expectedType, redex ?? expr),
        IDMap({
          expr.id: Ann(expectedType, redex),
          if (type is Var) type.id: Ann(expectedType, redex)
        }),
      );

/////// Check App
    } else if (expr is App) {
      final fnArgTypeVar = Var([...ctx.keys, ...expr.fn.freeVars].freshen('FN_ARG_TYPE_'));
      final fnRedexVar = Var([...ctx.keys, ...expr.fn.freeVars].freshen('FN_REDEX_'));
      Expr fnType = Fn.typ(false, null, fnArgTypeVar, expectedType);
      Expr fnRedex = expr.fn;
      TypeCtx inferences = const IDMap({});
      // TODO: persist partial state across loops?
      // TODO: force two loop iterations to get argType?
      // TODO: implicit? argID? match var names in expected type?
      final fnResult = _check(
        ctx.addAll([fnArgTypeVar.id, fnRedexVar.id]),
        fnType,
        fnRedexVar,
        expr.fn,
      );
      if (fnResult is CheckFailure) return fnResult.wrap('fn of $expr');
      if (fnResult is! CheckProgress) throw Exception();
      var newInferences = fnResult.inferences.without(fnArgTypeVar.id).without(fnRedexVar.id);
      inferences = inferences.union(newInferences);
      ctx = ctx.union(newInferences);

      Jdg(type: fnType, value: fnRedex) = fnResult.result;

      final argTypeVar = Var([...ctx.keys, ...expr.fn.freeVars].freshen('ARG_TYPE_'));
      final argRedexVar = Var([...ctx.keys, ...expr.fn.freeVars].freshen('ARG_REDEX_'));
      final argResult = _check(
        ctx.addAll([argTypeVar.id, argRedexVar.id]),
        fnType is Fn ? fnType.argType : argTypeVar,
        argRedexVar,
        expr.arg,
      );
      if (argResult is CheckFailure) return argResult.wrap('arg of $expr');
      if (argResult is! CheckProgress) throw Exception();

      newInferences = argResult.inferences.without(argTypeVar.id).without(argRedexVar.id);
      inferences = inferences.union(newInferences);
      ctx = ctx.union(newInferences);

      final Jdg(value: argRedex) = argResult.result;

      Expr doSubst(Expr fn, Expr def) => fn is Fn
          ? fn.argID != null
              ? fn.result.substExpr(fn.argID!, argRedex)
              : fn.result
          : def;

      return Progress(
        Jdg(
          doSubst(fnType, expectedType),
          doSubst(fnRedex, App(expr.implicit, fnRedex, argRedex)),
        ),
        inferences,
      );

/////// Check Fn
    } else if (expr case Fn(:var argID)) {
      if (argID != null && ctx.containsKey(argID)) {
        return Failure('shadowed variable $argID');
      }

      TypeCtx inferences = const IDMap({});

      final argTypeVar = Var([...ctx.keys, ...expr.argType.freeVars].freshen('ARG_TYPE_'));
      final argResult = _check(
        ctx.addAll([argTypeVar.id]),
        Type,
        expectedType is Fn ? expectedType.argType : argTypeVar,
        expr.argType,
      );

      if (argResult is CheckFailure) return argResult.wrap('arg type of $expr');
      if (argResult is! CheckProgress) throw Exception();
      var newInferences = argResult.inferences.without(argTypeVar.id);
      inferences = inferences.union(newInferences);
      ctx = ctx.union(newInferences);

      var Jdg(value: argTypeRedex) = argResult.result;

      final resTypeVar = Var([...ctx.keys, ...expr.result.freeVars].freshen('RES_TYPE_'));
      final resRedexVar = Var([...ctx.keys, ...expr.result.freeVars].freshen('RES_REDEX_'));
      final resResult = _check(
        // TODO: fill in redex somehow?
        (argID != null ? ctx.add(argID, Ann(argTypeRedex, null)) : ctx)
            .addAll([resTypeVar.id, resRedexVar.id]),
        // TODO: need to match var names here
        expr.kind == Fn.Typ
            ? Type
            : expectedType is Fn
                ? expectedType.result
                : resTypeVar,
        resRedexVar,
        expr.result,
      );
      if (resResult is CheckFailure) return resResult.wrap('arg type of $expr');
      if (resResult is! CheckProgress) throw Exception();
      newInferences = resResult.inferences.without(resTypeVar.id).without(resRedexVar.id);
      inferences = inferences.union(resResult.inferences);
      final Jdg(type: retType, value: retRedex) = resResult.result;

      if (argID != null) {
        argTypeRedex = inferences.get(argID)?.type ?? argTypeRedex;
        inferences = inferences.without(argID);
      }

      return Progress(
        Jdg(
          expr.kind == Fn.Typ ? Type : Fn(expr.implicit, Fn.Typ, argID, argTypeRedex, retType),
          Fn(expr.implicit, expr.kind, argID, argTypeRedex, retRedex),
        ),
        argID != null ? inferences.without(argID) : inferences,
      );
    } else {
      throw Exception('unexpected case ${expr.runtimeType}');
    }
  }

/////// Unify

  bool gotMore = true;
  TypeCtx inferences = const IDMap({});
  late Expr resultType;
  while (gotMore) {
    gotMore = false;

    final result = subCheck(ctx, expr);

    if (result is CheckFailure) return result.wrap();
    if (result is! CheckProgress) throw Exception();
    if (!result.inferences.isEmpty) gotMore = true;
    inferences = result.inferences;
    ctx = ctx.union(result.inferences);

    Jdg(type: resultType, value: expr) = result.result;

    final unifyResult = unify(ctx, reduce(ctx, expectedType), reduce(ctx, resultType));

    if (unifyResult is AssgnFailure) {
      return Failure(unifyResult.reason.wrap('checking expected type in:\n$expr'));
    }
    if (unifyResult is! AssgnProgress) throw Exception();
    if (!unifyResult.inferences.isEmpty) gotMore = true;
    inferences = inferences.union(unifyResult.inferences);
    ctx = ctx.union(unifyResult.inferences);
  }

  return Progress(
    Jdg(reduce(ctx, resultType), reduce(ctx, expr)),
    inferences,
  );
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
      if (ctx.get(a.id) == null || ctx.get(a.id)!.value == null) {
        return Progress(null, IDMap({a.id: Ann(Type, b)}));
      } else {
        return unify(ctx, ctx.get(a.id)!.value!, b);
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
      Var a => switch (ctx.get(a.id)) {
          Jdg(value: var redex) when redex != a => reduce(ctx, redex),
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
