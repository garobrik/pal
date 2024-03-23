// ignore_for_file: prefer_function_declarations_over_variables, constant_identifier_names

import 'lang.dart';

typedef Tokens = List<(String, int, int)>;
typedef Parser<T> = (T, Tokens) Function(Tokens);
const PAREN_FOR = {true: '<', false: '('};
const MATCHING_PAREN = {'(': ')', '<': '>', '[': ']', '{': '}'};
const SPECIAL_CHARS = ' \n<>()[]{},:.=-';

Tokens tokenize(String s) {
  final ret = <(String, int, int)>[];
  int line = 0;
  int col = 0;

  while (s.isNotEmpty) {
    var index = 0;
    while (index < s.length && !SPECIAL_CHARS.contains(s[index])) {
      index++;
    }

    if (index == 0) {
      if (s[0] == '\n') {
        line++;
        col = 0;
      } else {
        if (s[0] != ' ') {
          ret.add((s.substring(0, 1), line, col));
        }
        col++;
      }
      s = s.substring(1);
    } else {
      ret.add((s.substring(0, index), line, col));
      col += index;
      s = s.substring(index);
    }
  }
  return ret;
}

final Parser<Program> parseProgram = (tokens) {
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

Parser<void> _parseLit(String lit) => (tokens) {
      assert(tokens.isNotEmpty && tokens[0].$1 == lit, tokens.toString());
      return (null, tokens.tail);
    };

Parser<T> _then<T>(
  Parser<T> f1,
  Parser<void> f2,
) =>
    (tokens) {
      final (result, remaining) = f1(tokens);
      return (result, f2(remaining).$2);
    };

Parser<Expr<(int, int)>> _parseFn(bool implicit) => (tokens) {
      var (argType, remaining) = parseExpr(tokens);
      late final String? id;
      assert(remaining.isNotEmpty);
      switch ((argType, remaining[0].$1)) {
        case (Var(id: var varID), ':'):
          id = varID;
          (argType, remaining) = parseExpr(remaining.tail);
        default:
          id = null;
      }
      final pos = (tokens[0].$2, tokens[0].$3);

      tokens = remaining;
      assert(tokens.isNotEmpty);

      final ((result, next), kind) = switch (tokens) {
        [(',', _, _), ...var remaining] => switch (_parseFn(implicit)(remaining)) {
            (var fn, var next) => ((fn, next), (fn as Fn).kind)
          },
        [(var e, _, _), (var n, var line, var col), ...var remaining]
            when e == MATCHING_PAREN[PAREN_FOR[implicit]] =>
          switch ((implicit, n)) {
            (true, '(') => switch (_parseFn(false)(remaining)) {
                (var fn, var next) => ((fn, next), (fn as Fn).kind)
              },
            (_, '{') => (_then(parseExpr, _parseLit('}'))(remaining), Fn.Def),
            (_, '[') => (_then(parseExpr, _parseLit(']'))(remaining), Fn.Typ),
            _ => throw Exception('unexpected $n at $line:$col')
          },
        _ => throw Exception('unexpected $tokens')
      };

      return (Fn(implicit, kind, id, argType, result, t: pos), next);
    };

Parser<Expr<(int, int)>> _parseFnAppBody(bool implicit, Expr<(int, int)> fn) => (tokens) {
      assert(tokens.isNotEmpty);
      final (arg, remaining) = parseExpr(tokens);
      final (tok, line, col) = remaining[0];
      final end = MATCHING_PAREN[PAREN_FOR[implicit]]!;
      if (tok == end) {
        return _parseFnApp(App(implicit, fn, arg, t: (tokens[0].$2, tokens[0].$3)))(
          _parseLit(end)(remaining).$2,
        );
      } else if (tok == ',') {
        return _parseFnAppBody(implicit, App(implicit, fn, arg, t: (tokens[0].$2, tokens[0].$3)))(
          _parseLit(',')(remaining).$2,
        );
      } else {
        throw Exception('unexpected $tok at $line:$col');
      }
    };

Parser<Expr<(int, int)>> _parseFnApp(Expr<(int, int)> fn) => (tokens) {
      switch (tokens) {
        case [('(', _, _), ...var rest]:
          final (expr, remaining) = _parseFnAppBody(false, fn)(rest);
          return _parseFnApp(expr)(remaining);
        case [('<', _, _), ...var rest]:
          final (expr, remaining) = _parseFnAppBody(true, fn)(rest);
          return _parseFnApp(expr)(remaining);
        default:
          return (fn, tokens);
      }
    };

final Parser<Expr<(int, int)>> parseExpr = (tokens) {
  switch (tokens) {
    case [('<' || '(' || '[', _, _), ...final afterToken]:
      final (fn, rest) = switch (tokens[0].$1) {
        '<' => _parseFn(true),
        '(' => _parseFn(false),
        var t => throw Exception('unexpected $t')
      }(afterToken);
      return _parseFnApp(fn)(rest);
    case [(var token, var line, var col), ...final rest]:
      assert(!SPECIAL_CHARS.contains(token), tokens);
      return _parseFnApp(Var(token, t: (line, col)))(rest);
    case _:
      throw Exception('unexpected end');
  }
};

extension<T> on List<T> {
  List<T> get tail => sublist(1);
}
