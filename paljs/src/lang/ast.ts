import type {Pos} from './parse';

export type ID = string;

export type IDMap<T> = Record<ID, T>;
export type IDSet = IDMap<boolean>;

export type Ann = {
  type: Expr;
  value?: Expr;
};

export type Ctx = IDMap<Ann>;

export const set: (_: ID[]) => IDSet = (ids) => Object.fromEntries(ids.map((id) => [id, true]));
export const empty = <T>(map: IDMap<T>) => Object.keys(map).length === 0;
export const union: <T>(..._: Record<ID, T>[]) => Record<ID, T> = Object.assign;
export const difference = (a: IDSet, b: IDSet): IDSet =>
  set(Object.keys(a).filter((k) => !(k in b)));
export const add = <T>(map: IDMap<T>, key: ID | undefined, value: NoInfer<T>): IDMap<T> =>
  key ? {...map, [key]: value} : map;
export const keys = <T>(map: IDMap<T>): IDSet => set(Object.keys(map));
export const without = <T>(map: IDMap<T>, key: ID | undefined) => {
  if (!key) return map;
  map = {...map};
  delete map[key];
  return map;
};

const freshen = (id: ID) =>
  id.replace(/[0-9]*$/, (tail) => (tail.length === 0 ? 0 : parseInt(tail) + 1).toString());
export const freshIn = (ids: IDSet, id: ID) => {
  while (id in ids) {
    id = freshen(id);
  }
  return id;
};

export const introduce = (ctx: Ctx, id: ID, type: Expr) => {
  const v = freshIn(keys(ctx), `_${id}0`);
  ctx = add(ctx, v, {type});
  return [ctx, newVar(v)] as const;
};

export const isRigid = (e: Expr): boolean => {
  if (isVar(e)) return !isHole(e);
  if (isApp(e)) return isRigid(e.fn) && isRigid(e.arg);
  return isRigid(e.argType) && isRigid(e.result);
};

export const isHole = (v: ID | Var | undefined) => {
  if (typeof v === 'object') {
    v = v.id;
  }
  return v?.startsWith('_') ?? true;
};

export type Program = Binding[][];

export type Binding = {
  id: ID;
  type?: Expr;
  value?: Expr;
};

export type Expr = {meta?: Pos} & (Var | App | Fn);

export type Var = {kind: 'var'; id: ID};
export type App = {
  kind: 'app';
  implicit: boolean;
  fn: Expr;
  arg: Expr;
};

export type FnKind = 'def' | 'type';
export type Fn = {
  kind: FnKind;
  implicit: boolean;
  argID?: ID;
  argType: Expr;
  result: Expr;
};

export const newVar = (id: ID): Var => ({kind: 'var', id});

export const isVar = (expr: Expr): expr is Var => {
  return expr.kind === 'var';
};

export const isApp = (expr: Expr): expr is App => {
  return expr.kind === 'app';
};

export const isFn = (expr?: Expr): expr is Fn => {
  return expr?.kind === 'def' || expr?.kind === 'type';
};

export const freeVars = (expr: Expr): IDSet => {
  if (isVar(expr)) return set([expr.id]);
  else if (isApp(expr)) return union(freeVars(expr.fn), freeVars(expr.arg));
  return union(
    freeVars(expr.argType),
    difference(freeVars(expr.result), expr.argID ? set([expr.argID]) : {})
  );
};

export const freeHoles = (expr: Expr): IDSet => {
  if (isVar(expr) && isHole(expr)) return set([expr.id]);
  else if (isVar(expr)) return set([]);
  else if (isApp(expr)) return union(freeHoles(expr.fn), freeHoles(expr.arg));
  return union(
    freeHoles(expr.argType),
    difference(freeHoles(expr.result), expr.argID ? set([expr.argID]) : {})
  );
};

export const occurs = (expr: Expr, v: Var): boolean => {
  if (isVar(expr)) return expr.id === v.id;
  else if (isApp(expr)) return occurs(expr.fn, v) || occurs(expr.arg, v);
  return occurs(expr.argType, v) || (expr.argID != v.id && occurs(expr.result, v));
};

export const substExpr = (expr: Expr, from: ID | undefined, to: Expr): Expr => {
  if (!from) return expr;
  if (isVar(expr)) {
    return expr.id === from ? to : expr;
  } else if (isApp(expr)) {
    return {
      ...expr,
      fn: substExpr(expr.fn, from, to),
      arg: substExpr(expr.arg, from, to),
    };
  } else {
    if (expr.argID == from) {
      return {...expr, argType: substExpr(expr.argType, from, to)};
    } else if (expr.argID == null) {
      return {
        ...expr,
        argType: substExpr(expr.argType, from, to),
        result: substExpr(expr.result, from, to),
      };
    }
    const newArgID = freshIn(difference(freeVars(to), set([expr.argID])), expr.argID);

    const result = substExpr(expr.result, expr.argID, newVar(newArgID));

    return {
      ...expr,
      argType: substExpr(expr.argType, from, to),
      result: substExpr(result, from, to),
    };
  }
};

export const alphaEquiv = (
  a: Expr,
  b: Expr,
  ctxA: (ID | undefined)[] = [],
  ctxB: (ID | undefined)[] = []
): boolean => {
  if (isVar(a) && isVar(b)) {
    return ctxA.indexOf(a.id) == ctxB.indexOf(b.id) && (ctxA.includes(a.id) || a.id == b.id);
  } else if (isApp(a) && isApp(b)) {
    return (
      a.implicit === b.implicit &&
      alphaEquiv(a.fn, b.fn, ctxA, ctxB) &&
      alphaEquiv(a.arg, b.arg, ctxA, ctxB)
    );
  } else if (isFn(a) && isFn(b)) {
    return (
      a.implicit === b.implicit &&
      a.kind === b.kind &&
      alphaEquiv(a.argType, b.argType, ctxA, ctxB) &&
      alphaEquiv(a.result, b.result, [a.argID, ...ctxA], [b.argID, ...ctxB])
    );
  } else {
    return false;
  }
};

const typeID = 'Type';
export const Type = newVar(typeID);
