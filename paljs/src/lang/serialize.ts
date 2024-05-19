import {Binding, Expr, FnKind, ID, Program, Ctx, isApp, isFn, isHole, isVar} from './ast';
import {MATCHING_PAREN, parenFor} from './parse';

const parenthesize = (s: string, p: keyof typeof MATCHING_PAREN) => `${p}${s}${MATCHING_PAREN[p]}`;
export const indent = (s: string, times: number = 1) =>
  s
    .split('\n')
    .map((line) => (line.length === 0 ? line : `${'  '.repeat(times)}${line}`))
    .join('\n');

export const serializeBinding = (
  b: Binding,
  {lineLength = 80, withFullHoleNames}: {lineLength?: number; withFullHoleNames?: boolean} = {}
) => {
  let result = b.id;
  const type = b.type ? serializeExprIndent(lineLength, b.type, withFullHoleNames) : undefined;
  const value = b.value ? serializeExprIndent(lineLength, b.value, withFullHoleNames) : undefined;
  if (type != null) {
    result += ': ';
    let lines = type.split('\n');
    if (lines[0].length <= 100 - result.length) {
      result += lines[0];
      lines = lines.slice(1);
      if (lines.length !== 0) {
        result += '\n';
        result += lines.join('\n');
      }
    } else {
      result += '\n';
      result += indent(lines.join('\n'));
    }
  }
  if (value != null) {
    result += ' = ';
    let lines = value.split('\n');
    if (lines[0].length <= 100 - result.split('\n')[result.split('\n').length - 1].length) {
      result += lines[0];
      lines = lines.slice(1);
      if (lines.length !== 0) {
        result += '\n';
        result += lines.join('\n');
      }
    } else {
      result += '\n';
      result += indent(lines.join('\n'));
    }
  }
  return result;
};

const serializeModule = (
  m: Binding[],
  {
    lineLength = 80,
    lineSep = 2,
    withFullHoleNames,
  }: {lineLength: number; lineSep: number; withFullHoleNames?: boolean}
) => m.map((b) => serializeBinding(b, {lineLength, withFullHoleNames})).join('\n'.repeat(lineSep));

export const serializeCtx = (ctx: Ctx, lineLength = 80) => {
  return (
    '{\n' +
    indent(
      serializeModule(
        Object.entries(ctx).map(([id, {type, value}]) => ({id, type, value})),
        {lineLength: lineLength - 2, lineSep: 1, withFullHoleNames: true}
      )
    ) +
    '\n}\n'
  );
};

export const serializeProgram = (p: Program, {lineLength = 80}: {lineLength: number}) => {
  return (
    p
      .map((m) => serializeModule(m, {lineLength, lineSep: 2, withFullHoleNames: false}))
      .join('\n\n--------------------\n\n') + '\n'
  );
};

let _withFullHoleNames = false;

const serializeApp = (e: Expr, implicit: boolean, args: Expr[]): string => {
  if (isApp(e) && e.implicit === implicit) {
    return serializeApp(e.fn, implicit, [e.arg, ...args]);
  }
  const argString = parenthesize(args.map(serializeExpr).join(', '), parenFor(implicit));
  return `${serializeExpr(e)}${argString}`;
};

const serializeArg = (kind: FnKind, [argID, expr]: [ID | undefined, Expr]) => {
  const result = (() => {
    const idPart = isHole(argID) ? '_' : argID;
    const exprPart = serializeExpr(expr);
    if (kind === 'type') {
      if (idPart === '_') return exprPart;
      if (exprPart === '_') return `${idPart}:`;
      return `${idPart}: ${exprPart}`;
    } else {
      if (exprPart === '_') return idPart;
      if (idPart === '_') return `:${exprPart}`;
      return `${idPart}: ${exprPart}`;
    }
  })();
  return result;
};

const combineArgs = (implicit: boolean, kind: FnKind, args: [ID | undefined, Expr][]) =>
  args.length === 0
    ? ''
    : parenthesize(args.map((arg) => serializeArg(kind, arg)).join(', '), parenFor(implicit));

const serializeFn = (
  e: Expr,
  implicit: boolean,
  kind: FnKind,
  args: [ID | undefined, Expr][],
  explicitArgs: [ID | undefined, Expr][]
): string => {
  if (isFn(e) && e.kind === kind && !(implicit === false && e.implicit === true)) {
    if (e.implicit) {
      return serializeFn(e.result, e.implicit, kind, [...args, [e.argID, e.argType]], explicitArgs);
    } else {
      return serializeFn(e.result, e.implicit, kind, args, [...explicitArgs, [e.argID, e.argType]]);
    }
  }

  const argPart = combineArgs(true, kind, args);
  const explicitArgPart = combineArgs(false, kind, explicitArgs);
  const bodyPart = isVar(e)
    ? parenthesize(serializeExpr(e), parenFor(kind))
    : ' ' + parenthesize(` ${serializeExpr(e)} `, parenFor(kind));

  return `${argPart}${explicitArgPart}${bodyPart}`;
};

const serializeExpr = (e: Expr): string => {
  if (isVar(e)) {
    if (isHole(e) && !_withFullHoleNames) {
      return '_';
    }
    return e.id;
  } else if (isApp(e)) {
    return serializeApp(e, e.implicit, []);
  } else {
    return serializeFn(e, e.implicit, e.kind, [], []);
  }
};

const serializeAppIndent = (
  colRemaining: number,
  e: Expr,
  implicit: boolean,
  args: Expr[]
): string => {
  if (isApp(e) && e.implicit === implicit) {
    return serializeAppIndent(colRemaining, e.fn, implicit, [e.arg, ...args]);
  }
  const oneLine = serializeApp(e, implicit, args);
  if (oneLine.length < colRemaining) {
    return oneLine;
  }
  const lines = args.map((arg) => indent(_serializeExprIndent(colRemaining - 3, arg)));
  return `${_serializeExprIndent(colRemaining, e)}${parenFor(implicit)}
${lines.join(',\n')}
${MATCHING_PAREN[parenFor(implicit)]}`;
};

const serializeFnIndent = (
  colRemaining: number,
  e: Expr,
  implicit: boolean,
  kind: FnKind,
  args: [ID | undefined, Expr][],
  explicitArgs: [ID | undefined, Expr][]
): string => {
  if (isFn(e) && e.kind === kind && !(implicit === false && e.implicit === true)) {
    if (e.implicit) {
      return serializeFnIndent(
        colRemaining,
        e.result,
        e.implicit,
        kind,
        [...args, [e.argID, e.argType]],
        explicitArgs
      );
    } else {
      return serializeFnIndent(colRemaining, e.result, e.implicit, kind, args, [
        ...explicitArgs,
        [e.argID, e.argType],
      ]);
    }
  }

  const oneLine = serializeFn(e, implicit, kind, args, explicitArgs);
  if (oneLine.length < colRemaining) {
    return oneLine;
  }
  const argPart = combineArgs(true, kind, args);
  const explicitArgPart = combineArgs(false, kind, explicitArgs);

  return `${argPart}${explicitArgPart} ${parenFor(kind)}
${indent(_serializeExprIndent(colRemaining - 2, e))}
${MATCHING_PAREN[parenFor(kind)]}`;
};

const _serializeExprIndent = (colRemaining: number, e: Expr): string => {
  if (isVar(e)) return serializeExpr(e);
  if (isApp(e)) return serializeAppIndent(colRemaining, e, e.implicit, []);
  return serializeFnIndent(colRemaining, e, e.implicit, e.kind, [], []);
};

export const serializeExprIndent = (
  colRemaining: number,
  e: Expr,
  withFullHoleNames: boolean = true
) => {
  _withFullHoleNames = withFullHoleNames;
  return _serializeExprIndent(colRemaining, e);
};
