import {Expr, Fn, FnKind, Program, Var, isVar, newVar} from './ast';

export type Pos = [number, number];
type Token = [string, Pos];
type ParseCtx = [Token[], number];
type Parser<T> = (_: ParseCtx) => [T, ParseCtx];
type UnholeyParser<T> = (_: Token[]) => [T, Token[]];

export const parenFor = (implicit: boolean | FnKind) => {
  if (implicit === 'type') return '[';
  if (implicit === 'def') return '{';
  if (implicit) return '<';
  return '(';
};

export const MATCHING_PAREN = {
  '(': ')',
  '<': '>',
  '[': ']',
  '{': '}',
} as const;

const IN_WORD_CHARS = '_-';
const OUT_WORD_CHARS = ' \n<>()[]{},:.=';
const SPECIAL_CHARS = OUT_WORD_CHARS + IN_WORD_CHARS;

export const tokenize = (s: string): Token[] => {
  const ret: Token[] = [];
  let line = 0;
  let col = 0;

  while (s.length !== 0) {
    let index = 0;
    if (!SPECIAL_CHARS.includes(s[index])) {
      index++;
      while (index < s.length && !OUT_WORD_CHARS.includes(s[index])) {
        index++;
      }
    }

    if (index === 0) {
      if (s[0] === '\n') {
        line++;
        col = 0;
      } else {
        if (s[0] !== ' ') {
          ret.push([s.substring(0, 1), [line, col]]);
        }
        col++;
      }
      s = s.substring(1);
    } else {
      ret.push([s.substring(0, index), [line, col]]);
      col += index;
      s = s.substring(index);
    }
  }
  return ret;
};

export const parseProgram: UnholeyParser<Program> = (tokens) => {
  if (tokens.length === 0) {
    return [[[]], []];
  }
  if (tokens[0][0] == '-') {
    const remaining = parseProgram(tokens.slice(tokens.findIndex((tok) => tok[0] != '-')));
    return [[[], ...remaining[0]], remaining[1]];
  }
  if (SPECIAL_CHARS.includes(tokens[0][0])) {
    throw new Error(tokens.toString());
  }

  const id = tokens[0][0];
  tokens = tokens.slice(1);
  let type: Expr | undefined;
  if (tokens[0][0] == ':') {
    tokens = tokens.slice(1);
    [type, tokens] = parseExpr(tokens);
  }
  let value: Expr | undefined;
  if (tokens[0][0] == '=') {
    tokens = tokens.slice(1);
    [value, tokens] = parseExpr(tokens);
  }

  const [remaining] = parseProgram(tokens);
  return [[[{id, type, value}, ...remaining[0]], ...remaining.slice(1)], []];
};

const parseLit =
  (lit: string): Parser<null> =>
  ([tokens, numHoles]) => {
    if (tokens.length === 0 || tokens[0][0] !== lit) {
      throw new Error(`${tokens[0][0]} != ${lit} at ${tokens[0][1]}`);
    }
    return [null, [tokens.slice(1), numHoles]];
  };

const then =
  <T>(f1: Parser<T>, f2: Parser<null>): Parser<T> =>
  (ctx) => {
    const [result, remaining] = f1(ctx);
    return [result, f2(remaining)[1]];
  };

const parseFn =
  (implicit: boolean): Parser<Fn> =>
  (ctx) => {
    let id: string | undefined;
    let maybe: Expr | undefined;
    let argType: Expr | undefined;
    const [[[tok]]] = ctx;
    if (tok === ':') {
      [argType, ctx] = _parseExpr(ctx);
    } else {
      [maybe, ctx] = _parseExpr(ctx);
      const [[[token, [line, col]], ...rest], numHoles] = ctx;
      if (isVar(maybe!) && token === ':') {
        ctx = [rest, numHoles];
        id = maybe.id;
        maybe = undefined;
        const [[[token]]] = ctx;
        if (token != ',' && token !== MATCHING_PAREN[parenFor(implicit)]) {
          [argType, ctx] = _parseExpr(ctx);
        }
      } else if (token != ',' && token != MATCHING_PAREN[parenFor(implicit)]) {
        throw new Error(`unexpected ${token} at ${line}:${col}`);
      }
    }
    const [[[, pos]]] = ctx;

    const [[result, next], kind] = ((): [[Expr, ParseCtx], 'def' | 'type'] => {
      const [[[tok]]] = ctx;
      let [[, ...remaining], numHoles] = ctx;
      if (tok === ',') {
        const [fn, next] = parseFn(implicit)([remaining, numHoles]);
        return [[fn, next], fn.kind];
      }
      if (tok !== MATCHING_PAREN[parenFor(implicit)]) {
        throw new Error(`unexpected ${ctx}`);
      }
      [[, ...remaining], numHoles] = ctx;
      ctx = [remaining, numHoles];
      const [[[nextParen, [line, col]]]] = ctx;
      [[, ...remaining]] = ctx;

      if (implicit && nextParen === '(') {
        const [fn, next] = parseFn(false)([remaining, numHoles]);
        return [[fn, next], fn.kind];
      } else if (nextParen === '{' || nextParen === '[') {
        const result = then(_parseExpr, parseLit(MATCHING_PAREN[nextParen]))([remaining, numHoles]);

        return [result, nextParen === '{' ? 'def' : 'type'];
      }
      throw new Error(`unexpected ${nextParen} at ${line}:${col}`);
    })();

    ctx = next;

    if (maybe !== undefined) {
      if (kind === 'type') {
        argType = maybe;
      } else {
        id = (maybe as Var).id;
      }
    }

    if (argType === undefined) {
      const [tokens, numHoles] = ctx;
      argType = newVar(`_${numHoles}`);
      ctx = [tokens, numHoles + 1];
    }
    return [{implicit, kind, argID: id, argType, result, meta: pos}, ctx];
  };

const parseFnAppBody =
  (implicit: boolean, fn: Expr): Parser<Expr> =>
  (ctx) => {
    const [[[, pos]]] = ctx;
    const [arg, remaining] = _parseExpr(ctx);
    const [[[tok, [line, col]]]] = remaining;
    const end = MATCHING_PAREN[parenFor(implicit)];
    if (tok == end) {
      return parseFnApp({kind: 'app', implicit, fn, arg, meta: pos})(parseLit(end)(remaining)[1]);
    } else if (tok == ',') {
      return parseFnAppBody(implicit, {
        kind: 'app',
        implicit,
        fn,
        arg,
        meta: pos,
      })(parseLit(',')(remaining)[1]);
    } else {
      throw new Error(`unexpected ${tok} at ${line}:${col}`);
    }
  };

const parseFnApp =
  (fn: Expr): Parser<Expr> =>
  (ctx) => {
    if (ctx[0].length === 0) return [fn, ctx];
    const [[[tok], ...rest], numHoles] = ctx;
    if (tok === '(' || tok === '<') {
      const [expr, remaining] = parseFnAppBody(tok === '<', fn)([rest, numHoles]);
      return parseFnApp(expr)(remaining);
    }
    return [fn, ctx];
  };

const _parseExpr: Parser<Expr> = (ctx) => {
  const [[[, pos], ...rest]] = ctx;
  let [[[token]], numHoles] = ctx;
  if (token == '_') {
    token = `_${numHoles}`;
    numHoles++;
  }

  ctx = [rest, numHoles];

  const [initExpr, remaining] = (() => {
    if (token === '<' || token === '(') {
      return parseFn(token === '<')(ctx);
    }
    if (SPECIAL_CHARS.includes(token)) {
      throw new Error(`unexpected ${token} at ${pos}`);
    }
    return [{kind: 'var', id: token, meta: pos} as const, ctx];
  })();

  return parseFnApp(initExpr)(remaining);
};

export const parseExpr: UnholeyParser<Expr> = (tokens) => {
  const [result, [remaining]] = _parseExpr([tokens, 0]);
  return [result, remaining];
};
