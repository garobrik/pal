import {
  Ann,
  App,
  Expr,
  Fn,
  ID,
  IDSet,
  Program,
  Type,
  Ctx,
  Var,
  add,
  alphaEquiv,
  difference,
  empty,
  freeHoles,
  freeVars,
  freshIn,
  isApp,
  isFn,
  isHole,
  isRigid,
  isVar,
  keys,
  newVar,
  occurs,
  set,
  substExpr,
  union,
  without,
  introduce,
} from './ast';
import {indent, serializeBinding, serializeCtx, serializeExprIndent} from './serialize';

type Jdg = {
  type: Expr;
  value: Expr;
};

type Result<Obj> = Obj & {
  ctx: Ctx;
};

type Progress<T> = Done<T> & {
  needs: IDSet;
};

type Done<T> = Result<{
  value: T;
}>;

type Failure = {
  reason: string;
};

const mkProblem =
  <Args extends unknown[], T>(constructor: (ctx: Ctx, ..._: Args) => ProblemGen<T>) =>
  (...args: Args) =>
  (ctx: Ctx) =>
    constructor(ctx, ...args);

const trivial = <T>(value: T): Problem<T> => {
  // eslint-disable-next-line require-yield
  return mkProblem(function* (ctx) {
    return {ctx, value};
  })();
};

const impossible = <T>(reason: string): Problem<T> => {
  // eslint-disable-next-line require-yield
  return mkProblem(function* (): ProblemGen<T> {
    return {reason};
  })();
};

type ProblemGen<T> = Generator<Progress<T>, Done<T> | Failure, Ctx>;
type Problem<T> = (_: Ctx) => ProblemGen<T>;

const then = <T1, T2>(problem: Problem<T1>, f: (_: Done<T1>) => Done<T2>): Problem<T2> =>
  wrap(problem, (ctx) => [ctx, undefined], f);

const wrap = <T1, T2, S>(
  problem: Problem<T1>,
  onInput: (_: Ctx) => [Ctx, S],
  onOutput: (_: Done<T1> | Progress<T1>, state: S) => Done<T2>
): Problem<T2> => {
  return mkProblem(function* (ctx) {
    let state: S;
    [ctx, state] = onInput(ctx);
    const problemGen = problem(ctx);
    for (;;) {
      [ctx, state] = onInput(ctx);
      const next = problemGen.next(ctx);
      if ('reason' in next.value) {
        return next.value;
      }
      const mappedNext = onOutput(next.value, state);
      if ('needs' in next.value) {
        ctx = yield {...next.value, ...mappedNext};
      } else {
        return mappedNext;
      }
    }
  })();
};

const combineProblems = mkProblem(function* (
  ctx,
  ...factories: ((...prevs: Jdg[]) => Problem<Jdg>)[]
) {
  const probs: (ProblemGen<Jdg> | undefined)[] = factories.map(() => undefined);
  const results: (Jdg | undefined)[] = factories.map(() => undefined);
  const done = probs.map(() => false);
  const needs: IDSet[] = probs.map(() => ({}));
  loop: for (;;) {
    each: for (let i = 0; i < probs.length; i++) {
      if (done[i]) continue each;

      let fresh = false;
      if (probs[i] === undefined) {
        fresh = true;
        const args = results.slice(0, i);
        if (args.some((j) => j === undefined)) continue;
        const tryMkProblem = factories[i](...(args as Jdg[]));
        if (tryMkProblem !== undefined) {
          probs[i] = tryMkProblem(ctx);
        }
      }

      if (probs[i] !== undefined && (fresh || Object.keys(needs[i]).some((k) => ctx[k].value))) {
        const next = probs[i]!.next(ctx);
        if ('reason' in next.value) return next.value;
        done[i] = next.done!;
        results[i] = next.value.value;
        ctx = next.value.ctx;
        needs[i] = 'needs' in next.value ? next.value.needs : {};
      }
    }
    if (done.every((d) => d)) break loop;
    ctx = yield {ctx, value: results, needs: union(...needs)};
  }

  return {ctx, value: results};
});

const checkVar = mkProblem(function* (ctx, type: Expr | undefined, expr: Var): ProblemGen<Jdg> {
  for (;;) {
    if (!(expr.id in ctx)) {
      return {reason: `unknown var ${expr.id} in ${serializeCtx(ctx)}`};
    }
    const binding = ctx[expr.id];
    if (!isHole(expr)) {
      return {
        ctx,
        value: {...binding, value: binding.value ?? expr},
      };
    }
    if (binding.value === undefined) {
      ctx = yield {
        ctx,
        needs: set([expr.id]),
        value: {type: binding.type ?? type, value: expr},
      };
    } else {
      return yield* check(type, binding.value)(ctx);
    }
  }
});

const checkApp = mkProblem(function* (ctx, type: Expr | undefined, expr: App) {
  let argType: Expr;
  let resultTypeFn: Expr;
  [ctx, argType] = introduce(ctx, 'argType', Type);
  [ctx, resultTypeFn] = introduce(ctx, 'resultType', {
    kind: 'type',
    implicit: false,
    argType,
    result: Type,
  });

  const combined = combineProblems(
    () => check(undefined, expr.fn),
    () => check(undefined, expr.arg),
    (fn) =>
      unify(Type, fn.type, {
        kind: 'type',
        implicit: false,
        argType,
        argID: 'arg',
        result: {kind: 'app', implicit: false, fn: resultTypeFn, arg: newVar('arg')},
      }),
    (_, arg) => unify(Type, argType, arg.type)
  );

  return yield* then(combined, ({ctx, value: [fn, arg]}) => {
    // console.log(
    //   'checkApp then',
    //   serializeCtx(ctx),
    //   serializeBinding({id: '', type, value: expr}),
    //   '\n',
    //   serializeBinding({id: '', ...fn}),
    //   '\n',
    //   serializeBinding({id: '', ...arg})
    // );
    if (!fn || !arg) throw new Error('invariant violation');

    let resultType: Expr = {kind: 'app', implicit: false, fn: resultTypeFn, arg: arg.value};
    if (isFn(fn.type)) {
      resultType = fn.type.argID
        ? substExpr(fn.type.result, fn.type.argID, arg.value)
        : fn.type.result;
    }

    let result: Expr = {
      ...expr,
      fn: fn.value,
      arg: arg.value,
    };
    if (isFn(fn.value)) {
      const {argID, result: fnResult} = fn.value;
      result = argID ? substExpr(fnResult, argID, arg.value) : fnResult;
    }
    return {ctx, value: {type: resultType, value: result}};
  })(ctx);
});

const checkFn = (type: Expr | undefined, expr: Fn): Problem<Jdg> => {
  const combined = combineProblems(
    () => check(Type, expr.argType),
    (argType) =>
      wrap(
        check(expr.kind === 'type' ? Type : undefined, expr.result),
        (ctx) => [
          add(ctx, expr.argID, {type: argType.value}),
          {oldArgBinding: expr.argID ? ctx[expr.argID] : undefined},
        ],
        ({ctx, value}, {oldArgBinding}) => ({
          value,
          ctx: oldArgBinding ? add(ctx, expr.argID, oldArgBinding) : without(ctx, expr.argID),
        })
      )
  );

  return then(combined, ({ctx, value: [argType, result]}) => {
    let type: Expr;
    if (expr.kind === 'type') {
      type = Type;
    } else {
      type = {...expr, kind: 'type', argType: argType!.value, result: result!.type};
    }

    return {
      ctx,
      value: {type, value: {...expr, argType: argType!.value, result: result!.value}},
    };
  });
};

const check = (type: Expr | undefined, expr: Expr): Problem<Jdg> => {
  console.log(
    '    check\n',
    // indent(serializeCtx(ctx), 3),
    indent(serializeBinding({id: '', type, value: expr}, {withFullHoleNames: true}), 3)
  );
  return then(
    combineProblems(
      () =>
        isVar(expr)
          ? checkVar(type, expr)
          : isApp(expr)
          ? checkApp(type, expr)
          : checkFn(type, expr),
      (expr) => (type ? unify(Type, type, expr.type) : trivial(expr))
    ),
    ({ctx, value: [e]}) => ({ctx, value: e!})
  );
};

const unify = mkProblem(function* (ctx, type: Expr, expected: Expr, expr: Expr): ProblemGen<Jdg> {
  console.log(
    '    unify\n',
    indent(serializeExprIndent(100, expected), 3),
    '\n',
    indent(serializeExprIndent(100, expr), 3)
  );

  for (;;) {
    expected = reduce(ctx, expected);
    expr = reduce(ctx, expr);
    if (alphaEquiv(expected, expr)) return {ctx, value: {type, value: expr}};

    if (isVar(expr) && isHole(expr.id)) {
      if (occurs(expected, expr)) {
        return {reason: `cycle: ${expr} in ${expected}`};
      }
      console.log('    adding', expr.id, serializeExprIndent(80, expected, true));
      ctx = add(ctx, expr.id, {type, value: expected});
      return {ctx, value: {type, value: expected}};
    } else if (isVar(expected) && isHole(expected.id)) {
      return yield* unify(type, expr, expected)(ctx);
    } else if (expected === Type) {
      return {ctx, value: {type: Type, value: expr}};
    } else if (expr === Type) {
      return {ctx, value: {type: Type, value: expected}};
    } else if (isApp(expected) && isApp(expr)) {
      return yield* unifyApp(type, expected, expr)(ctx);
    } else if (isFn(expected) && isFn(expr)) {
      return yield* unifyFn(type, expected, expr)(ctx);
    }

    const needs = union(freeHoles(expected), freeHoles(expr));
    if (empty(needs)) break;
    ctx = yield {ctx, value: {type, value: expr}, needs};
  }

  return {reason: `can't unify ${expected} ${expr}`};
});

const unifyApp = mkProblem(function* (ctx, type: Expr, expected: Expr, expr: Expr) {
  for (;;) {
    let rigidHead: Expr | undefined;
    let iters = [expected, expr];
    let spines: [Expr, Expr][] = [];

    while (iters.every(isApp)) {
      if (iters.every(isRigid)) {
        if (alphaEquiv(iters[0], iters[1])) {
          rigidHead = iters[0];
          break;
        } else {
          return {reason: `can't unify ${expected} with ${expr}`};
        }
      }

      spines = [[iters[0], iters[1]], ...spines];
      iters = iters.map((v) => v.fn as App);
    }

    if (rigidHead === undefined) {
      ctx = yield {
        ctx,
        value: {type, value: expr},
        needs: union(freeHoles(expected), freeHoles(expr)),
      };
      expected = reduce(ctx, expected);
      expr = reduce(ctx, expr);
      continue;
    }

    const combined = combineProblems(...spines.map((a, b) => () => unify(undefined, a, b)));

    return yield* then(combined, ({ctx, value: args}) => {
      let result = rigidHead;
      for (const arg of args) {
        result = {kind: 'app', implicit: true, fn: result, arg: arg!.value};
      }
      return {ctx, value: {type, value: {...expr, arg: result}}};
    })(ctx);
  }
});

const unifyFn = (type: Expr, expected: Fn, expr: Fn): Problem<Jdg> => {
  if (expected.kind !== expr.kind) {
    return impossible(`fn kind mismatch`);
  }
  let argID: ID | undefined;
  let expectedResult = expected.result;
  let exprResult = expr.result;
  if (expected.argID && expr.argID) {
    argID = freshIn(union(freeVars(expected), freeVars(expr)), expr.argID);
    expectedResult = substExpr(expectedResult, expected.argID, newVar(argID));
    exprResult = substExpr(exprResult, expr.argID, newVar(argID));
  } else {
    argID = expected.argID ?? expr.argID;
  }

  const combined = combineProblems(
    () => unify(Type, expected.argType, expr.argType),
    (argType) =>
      wrap(
        unify(Type, expectedResult, exprResult),
        (ctx) => [
          add(ctx, argID, {type: argType.value}),
          {oldArgBinding: argID ? ctx[argID] : undefined},
        ],
        ({ctx, value}, {oldArgBinding}) => ({
          value,
          ctx: oldArgBinding ? add(ctx, expr.argID, oldArgBinding) : without(ctx, expr.argID),
        })
      )
  );

  return then(combined, ({ctx, value: [argType, result]}) => {
    let type: Expr;
    if (expr.kind === 'type') {
      type = Type;
    } else {
      type = {
        ...expr,
        kind: 'type',
        argType: argType!.value,
        result: result!.type,
      };
    }

    return {
      ctx,
      value: {type, value: {...expr, argType: argType!.value, result: result!.value}},
    };
  });
};

const reduce = (ctx: Ctx, expr: Expr): Expr => {
  if (isVar(expr)) {
    if (expr.id in ctx && ctx[expr.id].value && ctx[expr.id].value !== Type) {
      return reduce(ctx, ctx[expr.id].value!);
    }
    return expr;
  } else if (isApp(expr)) {
    const [fn, arg] = [reduce(ctx, expr.fn), reduce(ctx, expr.arg)];
    if (isFn(fn)) return reduce(ctx, substExpr(fn.result, fn.argID, arg));
    return {...expr, fn, arg};
  }
  return {
    ...expr,
    argType: reduce(ctx, expr.argType),
    result: reduce(without(ctx, expr.argID), expr.result),
  };
};

const checkExpr = (ctx: Ctx, type: Expr | undefined, expr: Expr) => {
  const holes = Object.keys(freeHoles(expr));
  const holesWithTypes = holes.flatMap<[ID, Ann]>((h) => {
    const ht = newVar(`${h}_type`);
    return [
      [h, {type: ht}],
      [ht.id, {type: Type}],
    ] as const;
  });
  ctx = union(ctx, Object.fromEntries(holesWithTypes));

  const problem = check(type, expr)(ctx);

  for (;;) {
    const next = problem.next(ctx);
    const {value} = next;
    if ('reason' in value) {
      return value;
    }
    ctx = value.ctx;
    if ('needs' in value) {
      const reason = {
        reason: `stuck ${Object.keys(value.needs)} ${serializeCtx(value.ctx)}${serializeBinding(
          {id: '', type, value: expr},
          {withFullHoleNames: true}
        )}\n${serializeBinding(
          {
            id: '',
            ...value.value,
          },
          {withFullHoleNames: true}
        )}`,
      };
      console.log(reason.reason);
      if (Object.keys(value.needs).every((k) => !ctx[k].value)) {
        return reason;
      }

      continue;
    }

    return value;
  }
};

export const checkProgram = (program: Program) => {
  let globalCtx: Ctx = {[Type.id]: {type: Type, value: Type}};

  for (const module of program) {
    let externalCtx: Ctx = {};
    let internalCtx = globalCtx;
    for (const binding of module) {
      console.log(binding.id);
      let expectedType: Expr | undefined;
      let externalType = binding.type;
      if (binding.type) {
        console.log('  type');
        const result = checkExpr(internalCtx, Type, binding.type);
        if ('reason' in result) return result;
        expectedType = result.value.value;
        while (!empty(difference(freeVars(externalType!), keys(internalCtx)))) {
          for (const v of Object.keys(difference(freeVars(externalType!), keys(internalCtx)))) {
            externalType = substExpr(externalType!, v, result.ctx[v].value!);
          }
        }
      }

      if (binding.value) {
        console.log('  body');
        const result = checkExpr(internalCtx, expectedType, binding.value);
        if ('reason' in result) return result;

        externalCtx = add(externalCtx, binding.id, {type: externalType ?? result.value.type!});
        internalCtx = add(internalCtx, binding.id, result.value);
      } else {
        externalCtx = add(externalCtx, binding.id, {type: externalType!});
        internalCtx = add(internalCtx, binding.id, {type: externalType!});
      }
    }

    globalCtx = union(globalCtx, externalCtx);
  }

  return globalCtx;
};
