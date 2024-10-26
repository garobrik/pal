import 'package:pal/src/ast.dart';

class Ann<T extends Object> {
  final Expr type;
  final Expr? value;

  const Ann(this.type, this.value);

  @override
  String toString() {
    final valueStr = switch (value) { Var(:var id) => id, _ => value?.toString() };
    final typeStr = switch (type) { Var(:var id) => id, _ => type.toString() };
    return '$valueStr: $typeStr';
  }
}

class Jdg<T extends Object> {
  final Expr type;
  final Expr value;

  const Jdg(this.type, this.value);

  @override
  String toString() {
    final valueStr = switch (value) { Var(:var id) => id, _ => value.toString() };
    final typeStr = switch (type) { Var(:var id) => id, _ => type.toString() };
    return '$valueStr: $typeStr';
  }
}

typedef Ctx = IDMap<Ann>;

(Ctx, Expr) introduce(Ctx ctx, ID id, Expr type) {
  final v = ctx.keys.freshen('_${id}0');
  ctx = ctx.add(v, Ann(type, null));
  return (ctx, Var(v));
}

class Problem {
  final Expr type;
  final Expr left;
  final Expr right;

  const Problem(this.type, this.left, this.right);

  @override
  operator ==(Object other) =>
      other is Problem &&
      type.alphaEquiv(other.type) &&
      left.alphaEquiv(other.left) &&
      right.alphaEquiv(other.right);

  @override
  int get hashCode => Object.hash(type, left, right);
}

(Ctx, Expr, List<Problem>) elaborateFn(Ctx ctx, Fn fn) {
  final argTypeElaboration = elaborate(ctx, Type, fn.argType);
  (ctx, _, _) = argTypeElaboration;
  final (_, _, argTypeProblems) = argTypeElaboration;

  final oldArgBinding = ctx.get(fn.argID);

  final resultElaboration = elaborate(
    ctx.add(fn.argID, Ann(fn.argType, null)),
    fn.kind == Fn.Typ ? Type : null,
    fn.result,
  );
  (ctx, _, _) = resultElaboration;
  final (_, resultType, resultProblems) = resultElaboration;

  ctx = oldArgBinding != null ? ctx.add(fn.argID, oldArgBinding) : ctx.without(fn.argID);

  return (
    ctx,
    fn.kind == Fn.Typ ? Type : Fn.typ(false, fn.argID, fn.argType, resultType),
    [...argTypeProblems, ...resultProblems]
  );
}

(Ctx, Expr, List<Problem>) elaborateApp(Ctx ctx, App app) {
  final fnElaboration = elaborate(ctx, null, app.fn);
  (ctx, _, _) = fnElaboration;
  final (_, fnType, fnProblems) = fnElaboration;
  final argElaboration = elaborate(ctx, null, app.arg);
  (ctx, _, _) = argElaboration;
  final (_, argType, argProblems) = argElaboration;

  late final Expr resultTypeFn;
  (ctx, resultTypeFn) = introduce(ctx, 'result', Fn.typ(false, null, argType, Type));

  late final List<Problem> resultProblems;
  (ctx, resultProblems) = solveStep(
    ctx,
    Problem(
      Type,
      fnType,
      Fn.typ(false, 'arg', argType, App(false, resultTypeFn, const Var('arg'))),
    ),
  );

  return (
    ctx,
    App(false, resultTypeFn, app.arg),
    [
      ...fnProblems,
      ...argProblems,
      ...resultProblems,
    ]
  );
}

(Ctx, Expr, List<Problem>) elaborate(Ctx ctx, Expr? expectedType, Expr expr) {
  var subproblems = switch (expr) {
    Var(:var id) => (ctx, ctx.get(id)!.type, <Problem>[]),
    App app => elaborateApp(ctx, app),
    Fn fn => elaborateFn(ctx, fn)
  };
  (ctx, _, _) = subproblems;
  var (_, type, problems) = subproblems;

  if (expectedType != null) {
    late final List<Problem> expectedProblems;
    (ctx, expectedProblems) = solveStep(ctx, Problem(Type, expectedType, type));
    problems = [...problems, ...expectedProblems];
  }

  return (ctx, type, problems);
}

Expr reduce(Ctx ctx, Expr expr) {
  if (expr case Var(:var id)) {
    final boundValue = ctx.get(id)?.value;
    if (boundValue == null || expr == Type) return expr;
    return reduce(ctx, boundValue);
  } else if (expr case App(:var fn, :var arg)) {
    (fn, arg) = (reduce(ctx, fn), reduce(ctx, arg));
    if (fn case Fn(:var argID, :var result)) {
      return reduce(ctx, result.substExpr(argID, result));
    }
    return App(expr.implicit, fn, arg);
  } else if (expr case Fn()) {
    return Fn(
      expr.implicit,
      expr.kind,
      expr.argID,
      reduce(ctx, expr.argType),
      reduce(ctx.without(expr.argID), expr.result),
    );
  }
  throw Error();
}

class UnificationException implements Exception {
  final String reason;

  UnificationException(this.reason);

  @override
  String toString() => 'UnificationException($reason)';
}

(Ctx, List<Problem>) solveApp(Ctx ctx, Expr type, App left, App right) {
  Expr? rigidHead;
  var (leftIter, rightIter) = (left as Expr, right as Expr);
  final spines = <(Expr, Expr)>[];

  while (leftIter is App && rightIter is App) {
    if (isRigid(leftIter) && isRigid(rightIter)) {
      if (leftIter.alphaEquiv(rightIter)) {
        rigidHead = leftIter;
        break;
      } else {
        throw UnificationException('can\'t unify $left $right');
      }
    }

    spines.insert(0, (leftIter.arg, rightIter.arg));
    (leftIter, rightIter) = (leftIter.fn, rightIter.fn);
  }

  if (rigidHead == null) {
    return (ctx, [Problem(type, left, right)]);
  }

  return (
    ctx,
    // TODO: what type to give the problem?
    [for (final (spineLeft, spineRight) in spines) Problem(Type, spineLeft, spineRight)]
  );
}

(Ctx, List<Problem>) solveFn(Ctx ctx, Expr type, Fn left, Fn right) {
  if (left.kind != right.kind) throw UnificationException('can\t unify $left $right');
  late final ID? argID;
  var (leftResult, rightResult) = (left.result, right.result);
  if (left.argID != null && right.argID != null) {
    argID = left.freeVars.union(right.freeVars).freshen(right.argID!);
    leftResult = leftResult.substExpr(left.argID!, Var(argID));
    rightResult = rightResult.substExpr(right.argID!, Var(argID));
  } else {
    argID = left.argID ?? right.argID;
  }

  return (
    ctx,
    [
      Problem(Type, left.argType, right.argType),
      // TODO: what type to expect?
      Problem(Type, leftResult, rightResult)
    ]
  );
}

(Ctx, List<Problem>) solveStep(Ctx ctx, Problem problem) {
  final type = reduce(ctx, problem.type);
  final left = reduce(ctx, problem.left);
  final right = reduce(ctx, problem.right);

  if (left.alphaEquiv(right)) {
    return (ctx, []);
  } else if (right is Var && isHole(right.id)) {
    if (left.occurs(right)) {
      throw UnificationException('cycle: $right in $left');
    }
    return (ctx.add(right.id, Ann(type, left)), []);
  } else if (left is Var && isHole(left.id)) {
    return solveStep(ctx, Problem(type, right, left));
  } else if (left == Type || right == Type) {
    return (ctx, []);
  } else if (left is App && right is App) {
    return solveApp(ctx, type, left, right);
  } else if (left is Fn && right is Fn) {
    return solveFn(ctx, type, left, right);
  }

  final holes = freeHoles(left).union(freeHoles(right));
  if (holes.isEmpty) throw UnificationException('can\'t unify $left $right');
  return (ctx, [Problem(type, left, right)]);
}

(Ctx, List<Problem>) solve(Ctx ctx, List<Problem> problems) {
  for (;;) {
    bool progress = false;
    problems = problems.expand((problem) {
      final step = solveStep(ctx, problem);
      (ctx, _) = step;
      final (_, newProblems) = step;
      if (newProblems.length != 1 || newProblems.first != problem) {
        progress = true;
      }
      return newProblems;
    }).toList();

    if (!progress) break;
  }

  return (ctx, problems);
}

(Ctx, Expr, Expr) checkExpr(Ctx ctx, Expr? type, Expr expr) {
  for (final hole in freeHoles(expr)) {
    final tp = '${hole}_type';
    ctx = ctx.add(hole, Ann(Var(tp), null)).add(tp, const Ann(Type, null));
  }

  final elaboration = elaborate(ctx, type, expr);
  (ctx, _, _) = elaboration;
  var (_, exprType, problems) = elaboration;

  (ctx, problems) = solve(ctx, problems);

  if (problems.isNotEmpty) {
    throw UnificationException('stuck: $problems');
  }

  return (ctx, reduce(ctx, exprType), reduce(ctx, expr));
}

Ctx checkProgram(Program program) {
  var globalCtx = IDMap({Type.id: const Ann(Type, Type)});

  for (final module in program) {
    Ctx externalCtx = IDMap.empty();
    Ctx internalCtx = globalCtx;

    for (final binding in module) {
      Expr? expectedType;
      Expr? externalType = binding.type;
      if (externalType != null) {
        late final Ctx resultCtx;
        (resultCtx, _, expectedType) = checkExpr(internalCtx, Type, externalType);
        while (freeHoles(externalType!).isNotEmpty) {
          for (final id in freeHoles(externalType)) {
            externalType = externalType!.substExpr(id, resultCtx.get(id)!.value!);
          }
        }
      }

      if (binding.value != null) {
        final (_, resultType, value) = checkExpr(internalCtx, expectedType, binding.value!);
        externalCtx = externalCtx.add(binding.id, Ann(externalType ?? resultType, null));
        internalCtx = internalCtx.add(
          binding.id,
          Ann(resultType, value),
        );
      } else {
        externalCtx = externalCtx.add(binding.id, Ann(externalType!, null));
        internalCtx = internalCtx.add(binding.id, Ann(externalType, null));
      }
    }

    globalCtx = globalCtx.union(externalCtx);
  }

  return globalCtx;
}
