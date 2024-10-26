// ignore_for_file: prefer_function_declarations_over_variables, constant_identifier_names, prefer_interpolation_to_compose_strings

import 'ast.dart';

typedef Token = (String, (int, int));
typedef Tokens = List<Token>;
typedef ParseCtx = (Tokens, int);
typedef Parser<T> = (T, ParseCtx) Function(ParseCtx);
typedef UnholeyParser<T> = (T, Tokens) Function(Tokens);
const PAREN_FOR = {true: '<', false: '('};
const MATCHING_PAREN = {'(': ')', '<': '>', '[': ']', '{': '}'};
const IN_WORD_CHARS = '_-';
const OUT_WORD_CHARS = ' \n<>()[]{},:.=';
const SPECIAL_CHARS = OUT_WORD_CHARS + IN_WORD_CHARS;
final HOLE_ID = RegExp(r'^_[0-9]*$');

Tokens tokenize(String s) {
  final ret = <Token>[];
  int line = 0;
  int col = 0;

  while (s.isNotEmpty) {
    var index = 0;
    if (!SPECIAL_CHARS.contains(s[index])) {
      index++;
      while (index < s.length && !OUT_WORD_CHARS.contains(s[index])) {
        index++;
      }
    }

    if (index == 0) {
      if (s[0] == '\n') {
        line++;
        col = 0;
      } else {
        if (s[0] != ' ') {
          ret.add((s.substring(0, 1), (line, col)));
        }
        col++;
      }
      s = s.substring(1);
    } else {
      ret.add((s.substring(0, index), (line, col)));
      col += index;
      s = s.substring(index);
    }
  }
  return ret;
}

final UnholeyParser<Program> parseProgram = (tokens) {
  if (tokens.isEmpty) {
    return ([[]], []);
  }
  if (tokens.first.$1 == '-') {
    final remaining = parseProgram(tokens.sublist(tokens.indexWhere((tok) => tok.$1 != '-')));
    return ([[], ...remaining.$1], remaining.$2);
  }
  assert(!SPECIAL_CHARS.contains(tokens[0].$1), tokens.toString());

  final id = tokens.first.$1;
  tokens = tokens.tail;
  Expr? type;
  if (tokens.first.$1 == ':') {
    tokens = tokens.tail;
    (type, tokens) = parseExpr(tokens);
  }
  Expr? value;
  if (tokens.first.$1 == '=') {
    tokens = tokens.tail;
    (value, tokens) = parseExpr(tokens);
  }

  final (remaining, []) = parseProgram(tokens);
  return (
    [
      [Binding(id, type, value), ...remaining.first],
      ...remaining.tail
    ],
    []
  );
};

Parser<void> _parseLit(String lit) => (ctx) {
      var (tokens, numHoles) = ctx;
      assert(tokens.isNotEmpty && tokens[0].$1 == lit, tokens.toString());
      return (null, (tokens.tail, numHoles));
    };

Parser<T> _then<T>(
  Parser<T> f1,
  Parser<void> f2,
) =>
    (tokens) {
      final (result, remaining) = f1(tokens);
      return (result, f2(remaining).$2);
    };

Parser<Expr> _parseFn(bool implicit) => (ctx) {
      String? id;
      Expr? maybe;
      Expr? argType;
      if (ctx case ([(':', _), ...var rest], var numHoles)) {
        id = null;
        (argType, ctx) = _parseExpr((rest, numHoles));
      } else {
        (maybe, ctx) = _parseExpr(ctx);
        final ([(token, (line, col)), ...rest], numHoles) = ctx;
        if ((maybe, token) case (Var(id: var varID), ':')) {
          ctx = (rest, numHoles);
          maybe = null;
          id = varID;
          var ([(token, _), ...], _) = ctx;
          if (token != ',' && token != MATCHING_PAREN[PAREN_FOR[implicit]]) {
            (argType, ctx) = _parseExpr(ctx);
          }
        } else if (token != ',' && token != MATCHING_PAREN[PAREN_FOR[implicit]]) {
          throw Exception('unexpected $token at $line:$col');
        }
      }
      final ([(_, pos), ...], _) = ctx;

      final ((result, next), kind) = switch (ctx) {
        ([(',', _), ...var remaining], var numHoles) => switch (
              _parseFn(implicit)((remaining, numHoles))) {
            (var fn, var next) => ((fn, next), (fn as Fn).kind)
          },
        ([(var e, _), (var n, (var line, var col)), ...var remaining], var numHoles)
            when e == MATCHING_PAREN[PAREN_FOR[implicit]] =>
          switch ((implicit, n)) {
            (true, '(') => switch (_parseFn(false)((remaining, numHoles))) {
                (var fn, var next) => ((fn, next), (fn as Fn).kind)
              },
            (_, '{') => (_then(_parseExpr, _parseLit('}'))((remaining, numHoles)), Fn.Def),
            (_, '[') => (_then(_parseExpr, _parseLit(']'))((remaining, numHoles)), Fn.Typ),
            _ => throw Exception('unexpected $n at $line:$col')
          },
        _ => throw Exception('unexpected $ctx')
      };
      ctx = next;

      if (maybe != null) {
        if (kind == Fn.Typ) {
          argType = maybe;
        } else {
          id = (maybe as Var).id;
        }
      }
      if (argType == null) {
        final (tokens, numHoles) = ctx;
        argType = Var('_$numHoles');
        ctx = (tokens, numHoles + 1);
      }
      return (Fn(implicit, kind, id, argType, result, t: pos), ctx);
    };

Parser<Expr> _parseFnAppBody(bool implicit, Expr fn) => (ctx) {
      var ([(_, pos), ...], _) = ctx;
      final (arg, remaining) = _parseExpr(ctx);
      final ([(tok, (line, col)), ...], _) = remaining;
      final end = MATCHING_PAREN[PAREN_FOR[implicit]]!;
      if (tok == end) {
        return _parseFnApp(App(implicit, fn, arg, t: pos))(
          _parseLit(end)(remaining).$2,
        );
      } else if (tok == ',') {
        return _parseFnAppBody(implicit, App(implicit, fn, arg, t: pos))(
          _parseLit(',')(remaining).$2,
        );
      } else {
        throw Exception('unexpected $tok at $line:$col');
      }
    };

Parser<Expr> _parseFnApp(Expr fn) => (ctx) {
      switch (ctx.$1) {
        case [('(', _), ...var rest]:
          final (expr, remaining) = _parseFnAppBody(false, fn)((rest, ctx.$2));
          return _parseFnApp(expr)(remaining);
        case [('<', _), ...var rest]:
          final (expr, remaining) = _parseFnAppBody(true, fn)((rest, ctx.$2));
          return _parseFnApp(expr)(remaining);
        default:
          return (fn, ctx);
      }
    };

final Parser<Expr> _parseExpr = (ctx) {
  var ([(token, pos), ...rest], numHoles) = ctx;

  if (token == '_') {
    token = '_$numHoles';
    numHoles++;
  }

  ctx = (rest, numHoles);

  final (initExpr, remaining) = switch (token) {
    '<' => _parseFn(true)(ctx),
    '(' => _parseFn(false)(ctx),
    _ => SPECIAL_CHARS.contains(token)
        ? throw Exception('unexpected $token')
        : (Var(token, t: pos), ctx),
  };

  return _parseFnApp(initExpr)(remaining);
};

final UnholeyParser<Expr> parseExpr = (tokens) {
  final (result, (remaining, _)) = _parseExpr((tokens, 0));
  return (result, remaining);
};

extension<T> on List<T> {
  List<T> get tail => sublist(1);
}
