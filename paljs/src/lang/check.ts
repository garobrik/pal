import {
  App,
  Expr,
  Fn,
  ID,
  IDSet,
  Program,
  Type,
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
  newVar,
  occurs,
  set,
  substExpr,
  union,
} from './ast';

type IDMap<T> = Record<ID, T>;
const add = <T>(map: IDMap<T>, key: ID | undefined, value: NoInfer<T>): IDMap<T> =>
  key ? {...map, [key]: value} : map;
const keys = <T>(map: IDMap<T>): IDSet => set(Object.keys(map));
const without = <T>(map: IDMap<T>, key: ID | undefined) => {
  if (!key) return map;
  map = {...map};
  delete map[key];
  return map;
};

type Ann = {
  type?: Expr;
  value?: Expr;
};

type Jdg = {
  type?: Expr;
  value: Expr;
};

type Result<Obj> = Obj & {
  ctx: TypeCtx;
};

type TypeCtx = IDMap<Ann>;

type Progress<T> = Done<T> & {
  needs: IDSet;
};

type Done<T> = Result<{
  value: T;
}>;

type Failure = {
  reason: string;
};

type Problem<T> = Generator<Progress<T>, Done<T> | Failure, TypeCtx>;

const then = <T1, T2>(
  ctx: TypeCtx,
  problem: Problem<T1>,
  f: (_: Done<T1>) => Done<T2>
): Problem<T2> => {
  return (function* () {
    for (;;) {
      const next = problem.next(ctx);
      if ('reason' in next.value) {
        return next.value;
      }
      const mappedNext = f(next.value);
      if ('needs' in next.value) {
        ctx = yield {...next.value, ...mappedNext};
      } else {
        return mappedNext;
      }
    }
  })();
};

function* combineProblems(
  ctx: TypeCtx,
  ...factories: ((ctx: TypeCtx, ...prevs: Jdg[]) => Problem<Jdg> | undefined)[]
): Problem<Jdg[]> {
  const probs: (Problem<Jdg> | undefined)[] = factories.map(() => undefined);
  const results: Jdg[] = [];
  const done = probs.map(() => false);
  const needs: IDSet[] = probs.map(() => ({}));
  while (!done.every((d) => d)) {
    for (let i = 0; i < probs.length; i++) {
      if (done[i]) continue;

      let fresh = false;
      if (probs[i] === undefined) {
        fresh = true;
        probs[i] = factories[i](ctx, ...results.slice(0, i));
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
    ctx = yield {ctx, value: results, needs: union(...needs)};
  }

  return {ctx, value: results};
}

function* check(ctx: TypeCtx, type: Expr | undefined, expr: Expr): Problem<Jdg> {
  if (isVar(expr)) {
    for (;;) {
      if (!(expr.id in ctx)) {
        return {reason: `unknown var ${expr.id}`};
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
        return yield* check(ctx, type, binding.value);
      }
    }
  } else if (isApp(expr)) {
    const combined = combineProblems(
      ctx,
      (ctx) => check(ctx, undefined, expr.fn),
      (ctx) => check(ctx, undefined, expr.arg),
      (ctx, fn, arg) => {
        if (isFn(fn.type) && arg.type !== undefined) {
          return unify(ctx, Type, fn.type.argType, arg.type);
        }
      }
    );

    return yield* then(ctx, combined, ({ctx, value: [fn, arg]}) => {
      let result: Expr = {
        ...expr,
        fn: fn.value,
        arg: arg.value,
      };
      if (isFn(fn.value)) {
        const {argID, result: fnResult} = fn.value;
        result = argID ? substExpr(fnResult, argID, arg.value) : fnResult;
      }
      return {ctx, value: {value: result}};
    });
  } else {
    const oldArgBinding = expr.argID ? ctx[expr.argID] : undefined;

    const combined = combineProblems(
      ctx,
      (ctx) => check(ctx, Type, expr.argType),
      (ctx, argType) =>
        then(
          ctx,
          check(
            add(ctx, expr.argID, argType),
            expr.kind === 'type' ? Type : undefined,
            expr.result
          ),
          (result) => ({...result, ctx: add(result.ctx, expr.argID, oldArgBinding as Ann)})
        )
    );

    return yield* then(ctx, combined, ({ctx, value: [argType, result]}) => {
      let type: Expr | undefined;
      if (expr.kind === 'type') {
        type = Type;
      } else if (result.type) {
        type = {...expr, kind: 'type', argType: argType.value, result: result.type};
      }

      return {
        ctx,
        value: {type, value: {...expr, argType: argType.value, result: result.value}},
      };
    });
  }
}

function* unify(ctx: TypeCtx, type: Expr, expected: Expr, expr: Expr): Problem<Jdg> {
  if (alphaEquiv(expected, expr)) return {ctx, value: {type, value: expr}};

  if (isVar(expr) && isHole(expr.id)) {
    if (occurs(expected, expr)) {
      return {reason: `cycle: ${expr} in ${expected}`};
    }
    ctx = add(ctx, expr.id, {type, value: expected});
    return {ctx, value: {type, value: expected}};
  } else if (isVar(expected) && isHole(expected.id)) {
    return yield* unify(ctx, type, expr, expected);
  } else if (expected === Type) {
    return {ctx, value: {type: Type, value: expr}};
  } else if (expr === Type) {
    return {ctx, value: {type: Type, value: expected}};
  } else if (isApp(expected) && isApp(expr)) {
    return yield* unifyApp(ctx, type, expected, expr);
  } else if (isFn(expected) && isFn(expr)) {
    return yield* unifyFn(ctx, type, expected, expr);
  }

  return {reason: `can't unify ${expected} ${expr}`};
}

function* unifyApp(ctx: TypeCtx, type: Expr, expected: Expr, expr: Expr): Problem<Jdg> {
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

    const combined = combineProblems(
      ctx,
      ...spines.map((a, b) => (ctx: TypeCtx) => unify(ctx, undefined, a, b))
    );

    return yield* then(ctx, combined, ({ctx, value: args}) => {
      let result = rigidHead;
      for (const arg of args) {
        result = {kind: 'app', implicit: true, fn: result, arg: arg.value};
      }
      return {ctx, value: {type, value: {...expr, arg: result}}};
    });
  }
}

function* unifyFn(ctx: TypeCtx, type: Expr, expected: Fn, expr: Fn): Problem<Jdg> {
  if (expected.kind !== expr.kind) {
    return {reason: `fn kind mismatch`};
  }
  let argID: ID | undefined;
  let expectedResult = expected.result;
  let exprResult = expr.result;
  if (expected.argID && expr.argID) {
    argID = freshIn(union(keys(ctx), freeVars(expected), freeVars(expr)), expr.argID);
    expectedResult = substExpr(expectedResult, expected.argID, newVar(argID));
    exprResult = substExpr(exprResult, expr.argID, newVar(argID));
  }

  const oldArgBinding = argID ? ctx[argID] : undefined;

  const combined = combineProblems(
    ctx,
    (ctx) => unify(ctx, Type, expected.argType, expr.argType),
    (ctx, argType) =>
      then(
        ctx,
        unify(
          argID ? add(ctx, argID, {type: argType.value}) : ctx,
          Type,
          expectedResult,
          exprResult
        ),
        (result) => ({...result, ctx: add(result.ctx, expr.argID, oldArgBinding as Ann)})
      )
  );

  return yield* then(ctx, combined, ({ctx, value: [argType, result]}) => {
    let type: Expr | undefined;
    if (expr.kind === 'type') {
      type = Type;
    } else if (result.type) {
      type = {
        ...expr,
        kind: 'type',
        argType: argType.value,
        result: result.type,
      };
    }

    return {
      ctx,
      value: {type, value: {...expr, argType: argType.value, result: result.value}},
    };
  });
}

const reduce = (ctx: TypeCtx, expr: Expr): Expr => {
  if (isVar(expr)) {
    if (ctx[expr.id].value && ctx[expr.id].value !== Type) return reduce(ctx, ctx[expr.id].value!);
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

const checkExpr = (ctx: TypeCtx, type: Expr | undefined, expr: Expr) => {
  const holes = Object.keys(freeHoles(expr));
  const holesWithTypes = holes.flatMap<[ID, Ann]>((h) => {
    const ht = newVar(`${h}_type`);
    return [
      [h, {type: ht}],
      [ht.id, {type: Type}],
    ] as const;
  });
  ctx = union(ctx, Object.fromEntries(holesWithTypes));

  const problem = check(ctx, type, expr);

  for (;;) {
    const {value} = problem.next(ctx);
    if ('reason' in value) {
      return value;
    }
    if ('needs' in value) {
      if (Object.keys(value.needs).every((k) => !ctx[k].value)) {
        return {reason: 'stuck'};
      }

      continue;
    }

    return value;
  }
};

export const checkProgram = (program: Program) => {
  let globalCtx: TypeCtx = {[Type.id]: {type: Type, value: Type}};

  for (const module of program) {
    let externalCtx: TypeCtx = {};
    let internalCtx = globalCtx;
    for (const binding of module) {
      let expectedType: Expr | undefined;
      let externalType = binding.type;
      if (binding.type) {
        const result = checkExpr(internalCtx, Type, binding.type);
        if ('reason' in result) return result;
        while (!empty(difference(freeVars(externalType!), keys(internalCtx)))) {
          for (const v of Object.keys(difference(freeVars(externalType!), keys(internalCtx)))) {
            externalType = substExpr(externalType!, v, result.ctx[v].value!);
          }
        }
      }

      if (binding.value) {
        const result = checkExpr(internalCtx, expectedType, binding.value);
        if ('reason' in result) return result;

        externalCtx = add(externalCtx, binding.id, {type: externalType ?? result.value.type!});
        internalCtx = add(internalCtx, binding.id, result.value);
      } else {
        externalCtx = add(externalCtx, binding.id, {type: externalType});
        internalCtx = add(internalCtx, binding.id, {type: externalType});
      }
    }

    globalCtx = union(globalCtx, externalCtx);
  }

  return globalCtx;
};
