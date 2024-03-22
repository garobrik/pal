// ignore_for_file: constant_identifier_names

import 'dart:collection';

typedef ID = String;

extension IDExtension on ID {
  ID get freshen => this.replaceFirstMapped(
        RegExp('[0-9]*\$'),
        (match) => ((int.tryParse(match[0]!) ?? 0) + 1).toString(),
      );
}

typedef Tokens = List<(String, int, int)>;
typedef Parser<T> = (T, Tokens) Function(Tokens);

sealed class Expr<T extends Object> {
  final T? t;
  const Expr(this.t);

  @override
  String toString() => _serializeIndent(80);

  String _serializeApp(List<Expr<Object>> args) {
    switch (this) {
      case App(:var fn, :var arg):
        return fn._serializeApp([arg, ...args]);
      default:
        return '${this._serialize()}(${args.map((arg) => arg._serialize()).join(', ')})';
    }
  }

  String _serializeFn(FnKind kind, List<(ID?, Expr<Object>)> args) {
    switch (this) {
      case Fn(kind: var thisKind, :var argID, :var argType, result: var body) when thisKind == kind:
        return body._serializeFn(kind, [...args, (argID, argType)]);
      default:
        final argPart =
            '${kind == Fn.Def ? '(' : '['}${args.map((pair) => pair.$1 == null ? pair.$2._serialize() : '${pair.$1}: ${pair.$2._serialize()}').join(', ')}${kind == Fn.Def ? ')' : ']'}';
        final bodyPart = this is Var ? '{${this._serialize()}}' : '{ ${this._serialize()} }';
        return '$argPart$bodyPart';
    }
  }

  String _serialize() {
    switch (this) {
      case Var(:var id):
        return id;
      case App():
        return this._serializeApp([]);
      case Fn(:var kind):
        return this._serializeFn(kind, []);
    }
  }

  String _serializeAppIndent(int colRemaining, List<Expr<Object>> args) {
    switch (this) {
      case App(:var fn, :var arg):
        return fn._serializeAppIndent(colRemaining, [arg, ...args]);
      default:
        final oneLine = _serializeApp(args);
        if (oneLine.length < colRemaining) {
          return oneLine;
        }
        final lines = args.map((arg) => arg._serializeIndent(colRemaining - 3).indent);
        return '''
$this(
${lines.join(',\n')}
)''';
    }
  }

  String _serializeFnIndent(int colRemaining, FnKind kind, List<(ID?, Expr<Object>)> args) {
    switch (this) {
      case Fn(kind: var thisKind, :var argID, :var argType, result: var body) when thisKind == kind:
        return body._serializeFnIndent(colRemaining, kind, [...args, (argID, argType)]);
      default:
        final oneLine = _serializeFn(kind, args);
        if (oneLine.length < colRemaining) {
          return oneLine;
        }
        final argPart =
            '${kind == Fn.Def ? '(' : '['}${args.map((pair) => pair.$1 == null ? '${pair.$2}' : '${pair.$1}: ${pair.$2}').join(', ')}${kind == Fn.Def ? ')' : ']'}';
        return '''$argPart {
${this._serializeIndent(colRemaining - 2).indent}
}''';
    }
  }

  String _serializeIndent(int colRemaining) {
    switch (this) {
      case Var(:var id):
        return id;
      case App():
        return this._serializeAppIndent(colRemaining, []);
      case Fn(:var kind):
        return this._serializeFnIndent(colRemaining, kind, []);
    }
  }

  static const _specialChars = ' \n<>()[]{},:.';
  static Tokens tokenize(String s) {
    final ret = <(String, int, int)>[];
    int line = 0;
    int col = 0;

    while (s.isNotEmpty) {
      var index = 0;
      while (index < s.length && !_specialChars.contains(s[index])) {
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

  static Parser<void> _parseLit(String lit) => (tokens) {
        assert(tokens.isNotEmpty && tokens[0].$1 == lit, tokens.toString());
        return (null, tokens.sublist(1));
      };

  static Parser<T> _then<T>(
    Parser<T> f1,
    Parser<void> f2,
  ) =>
      (tokens) {
        final (result, remaining) = f1(tokens);
        return (result, f2(remaining).$2);
      };

  static Parser<Expr<(int, int)>> _parseFn(FnKind kind, String endParen) => (tokens) {
        var (argType, remaining) = _parse(tokens);
        late final String? id;
        assert(remaining.isNotEmpty);
        switch ((argType, remaining[0].$1)) {
          case (Var(id: var varID), ':'):
            id = varID;
            (argType, remaining) = _parse(remaining.sublist(1));
          default:
            id = null;
        }
        final pos = (tokens[0].$2, tokens[0].$3);

        tokens = remaining;
        assert(tokens.isNotEmpty);
        final (result, next) = switch (tokens) {
          [(',', _, _), ...var remaining] => _parseFn(kind, endParen)(remaining),
          [(var e, _, _), (var n, var line, var col), ...var remaining] when e == endParen =>
            switch ((e, n)) {
              ('>', '(') => _parseFn(kind, ')')(remaining),
              (_, '{') => _then(_parse, _parseLit('}'))(remaining),
              _ => throw Exception('unexpected $n at $line:$col')
            },
          _ => throw Exception('unexpected $tokens')
        };

        return (Fn(kind, id, argType, result, pos), next);
      };

  static Parser<Expr<(int, int)>> _parseFnAppBody(Expr<(int, int)> fn, String end) => (tokens) {
        assert(tokens.isNotEmpty);
        final (arg, remaining) = _parse(tokens);
        final (tok, line, col) = remaining[0];
        if (tok == end) {
          return _parseFnApp(
            _parseLit(end)(remaining).$2,
            App(fn, arg, (tokens[0].$2, tokens[0].$3)),
          );
        } else if (tok == ',') {
          return _parseFnAppBody(App(fn, arg, (tokens[0].$2, tokens[0].$3)), end)(
            _parseLit(',')(remaining).$2,
          );
        } else {
          throw Exception('unexpected $tok at $line:$col');
        }
      };

  static (Expr<(int, int)>, Tokens) _parseFnApp(Tokens tokens, Expr<(int, int)> fn) {
    switch (tokens) {
      case [('(', _, _), ...var rest]:
        final (expr, remaining) = _parseFnAppBody(fn, ')')(rest);
        return _parseFnApp(remaining, expr);
      case [('<', _, _), ...var rest]:
        final (expr, remaining) = _parseFnAppBody(fn, '>')(rest);
        return _parseFnApp(remaining, expr);
      default:
        return (fn, tokens);
    }
  }

  static (Expr<(int, int)>, Tokens) _parse(Tokens tokens) {
    switch (tokens) {
      case [('<' || '(' || '[', _, _), ...final afterToken]:
        final (fn, rest) = switch (tokens[0].$1) {
          '<' => _parseFn(Fn.Def, '>'),
          '(' => _parseFn(Fn.Def, ')'),
          '[' => _parseFn(Fn.Typ, ']'),
          var t => throw Exception('unexpected $t')
        }(afterToken);
        return _parseFnApp(rest, fn);
      case [(var token, var line, var col), ...final rest]:
        assert(!_specialChars.contains(token), tokens);
        return _parseFnApp(rest, Var(token, (line, col)));
      case _:
        throw Exception('unexpected end');
    }
  }

  static Expr<(int, int)> parse(String s) => _parse(tokenize(s)).$1;
  Set<ID> get freeVars => switch (this) {
        Var(:var id) => {id},
        Fn(:var argID, :var result, :var argType) =>
          result.freeVars.difference({argID}).union(argType.freeVars),
        App(:var fn, :var arg) => fn.freeVars.union(arg.freeVars),
      };

  Expr substExpr(ID from, Expr to) {
    switch (this) {
      case Var(:var id):
        return id == from ? to : this;
      case App(:var fn, :var arg):
        return App(fn.substExpr(from, to), arg.substExpr(from, to));
      case Fn(:var kind, :var argID, :var argType, :var result):
        if (argID == from) {
          return Fn(kind, argID, argType.substExpr(from, to), result);
        } else if (argID == null) {
          return Fn(kind, argID, argType.substExpr(from, to), result.substExpr(from, to));
        }
        var newArgID = argID;

        while (to.freeVars.contains(newArgID)) {
          newArgID = newArgID.freshen;
        }

        if (argID != newArgID) result = result.substExpr(argID, Var(newArgID));

        return Fn(kind, newArgID, argType.substExpr(from, to), result.substExpr(from, to));
    }
  }

  bool alphaEquiv(Expr b, [List<String?> ctxA = const [], List<String?> ctxB = const []]) =>
      switch ((this, b)) {
        (Var(id: var a), Var(id: var b)) =>
          ctxA.indexOf(a) == ctxB.indexOf(b) && (ctxA.contains(a) || (a == b)),
        (App a, App b) => a.fn.alphaEquiv(b.fn, ctxA, ctxB) && a.arg.alphaEquiv(b.arg, ctxA, ctxB),
        (Fn a, Fn b) => a.kind == b.kind &&
            a.argType.alphaEquiv(b.argType, ctxA, ctxB) &&
            a.result.alphaEquiv(b.result, [a.argID, ...ctxA], [b.argID, ...ctxB]),
        _ => false,
      };

  @override
  bool operator ==(Object other) => other is Expr && this.alphaEquiv(other);

  int _hashCode(List<String?> ctx) => switch (this) {
        Var v => Hash.all([!ctx.contains(v.id) ? v.id.hashCode : ctx.indexOf(v.id).hashCode]),
        App fn => Hash.all([fn.fn._hashCode(ctx), fn.arg._hashCode(ctx)]),
        Fn f => Hash.all([
            f.kind.hashCode,
            f.argType._hashCode(ctx),
            f.result._hashCode([f.argID, ...ctx])
          ]),
      };

  @override
  int get hashCode => _hashCode(const []);
}

class Var<T extends Object> extends Expr<T> {
  final ID id;

  const Var(this.id, [super.t]);
}

class App<T extends Object> extends Expr<T> {
  final Expr fn;
  final Expr arg;

  const App(this.fn, this.arg, [super.t]);
}

enum FnKind { Def, Typ }

class Fn<T extends Object> extends Expr<T> {
  static const Def = FnKind.Def;
  static const Typ = FnKind.Typ;

  final FnKind kind;
  final ID? argID;
  final Expr argType;
  final Expr result;

  const Fn(this.kind, this.argID, this.argType, this.result, [super.t]);
}

const _typeID = 'Type';
const Type = Var(_typeID);

// Type Checking

sealed class Result<T> {
  const Result();

  bool get isFailure => switch (this) {
        Failure() => true,
        Success() => false,
      };

  T? get success => this is Success<T> ? (this as Success<T>).result : null;

  Result<R> map<R>(R Function(T) f) => switch (this) {
        Success(:var result) => Success(f(result)),
        Failure(:var msg) => Failure(msg),
      };

  Result<T> wrap(String ctx) => switch (this) {
        Failure(:var msg) => Failure(msg.wrap(ctx)),
        _ => this,
      };

  Result<T2> castFailure<T2>() => switch (this) {
        Failure(:var msg) => Failure(msg),
        _ => throw Exception(),
      };
}

class Success<T> extends Result<T> {
  final T result;

  const Success(this.result);

  @override
  String toString() => 'Success($result)';
}

class Failure<T> extends Result<T> {
  final String msg;

  const Failure(this.msg);

  @override
  String toString() => 'Failure($msg)';

  Failure<T2> cast<T2>() => Failure(msg);
}

extension IDMapOps<T> on Map<ID, T> {
  T? get(ID key) => this[key];
  Map<ID, T> add(ID key, T value) => {...this, key: value};
  Map<ID, T> union(Map<ID, T> other) => {...this, ...other};
  Map<ID, T> without(ID key) {
    final map = {...this};
    map.remove(key);
    return map;
  }

  bool equals(Map<ID, T> other) {
    if (length != other.length) return false;
    for (final MapEntry(:key, :value) in entries) {
      if (other.get(key) != value) return false;
    }
    return true;
  }

  EvalCtx restrict(Iterable<ID> ids) => {
        for (final id in ids)
          if (this.containsKey(id)) id: this.get(id)
      };
}

typedef TypeCtx = Map<ID, (Expr?, Expr?)>;
typedef EvalCtx = Map<ID, Object?>;

Result<(TypeCtx, Expr, Expr)> check(TypeCtx ctx, Expr? expectedType, Expr expr) {
  late final Expr actualType;
  late final Expr redex;

  switch (expr) {
    case Var expr:
      final bound = ctx.get(expr.id);
      if (bound == null) return Failure('unknown var $expr in ctx:\n  $ctx');
      if (bound.$1 == null && expectedType != null) {
        ctx = ctx.add(expr.id, (expectedType, bound.$2));
        actualType = expectedType;
      } else if (bound.$1 != null) {
        actualType = bound.$1!;
      } else {
        return Failure('unknown var type for $expr');
      }
      final (_, boundRedex) = bound;
      redex = boundRedex ?? expr;

    case App expr:
      final argResult = check(ctx, null, expr.arg);
      if (argResult.isFailure) return argResult.wrap('arg of $expr');
      final (argCtx, argType, argRedex) = argResult.success!;
      ctx = argCtx;

      final fnResult = check(
        ctx,
        null,
        expr.fn,
      );
      if (fnResult.isFailure) return fnResult.wrap('fn of $expr');
      final (fnCtx, fnType, fnRedex) = fnResult.success!;
      ctx = fnCtx;

      switch (fnType) {
        case Fn(kind: Fn.Typ, :var argID, argType: var fnArgType, result: var retType):
          final assignableResult = assignable(ctx, fnArgType, argType);
          if (assignableResult.isFailure) {
            return assignableResult.wrap('checking passed arg in fnapp:\n$expr').castFailure();
          }
          actualType = argID != null ? retType.substExpr(argID, argRedex) : retType;
          redex = switch (fnRedex) {
            Fn(kind: Fn.Def, :var argID, result: var body) =>
              argID != null ? body.substExpr(argID, argRedex) : body,
            _ => App(fnRedex, argRedex),
          };
        case _:
          return Failure('tried to apply non fn ${expr.fn} of type $fnType');
      }

    case Fn expr:
      final argResult = check(ctx, Type, expr.argType);
      if (argResult.isFailure) return argResult.wrap('arg type of $expr');
      final (argCtx, _, argRedex) = argResult.success!;
      ctx = argCtx;

      if (ctx.containsKey(expr.argID)) {
        return Failure('shadowed variable ${expr.argID}');
      }
      final retResult = check(
        expr.argID != null ? ctx.add(expr.argID!, (argRedex, null)) : ctx,
        expr.kind == Fn.Typ ? Type : null,
        expr.result,
      );
      if (retResult.isFailure) return retResult.wrap('return type of $expr');
      final (retCtx, retType, retRedex) = retResult.success!;

      final oldArgBinding = expr.argID == null ? null : ctx.get(expr.argID!);
      ctx = retCtx;
      if (expr.argID != null) {
        ctx = ctx.without(expr.argID!);
        if (oldArgBinding != null) ctx = ctx.add(expr.argID!, oldArgBinding);
      }

      actualType = expr.kind == Fn.Typ ? Type : Fn(Fn.Typ, expr.argID, argRedex, retType);
      redex = Fn(expr.kind, expr.argID, argRedex, retRedex);
  }

  if (expectedType != null) {
    final assignableResult = assignable(ctx, reduce(ctx, expectedType), reduce(ctx, actualType))
        .wrap('checking expected type in:\n$expr');
    if (assignableResult.isFailure) return (assignableResult as Failure).cast();
    ctx = assignableResult.success!;
  }
  return Success((ctx, reduce(ctx, actualType), reduce(ctx, redex)));
}

Expr reduce(TypeCtx ctx, Expr a) => switch (a) {
      Var a =>
        ctx.get(a.id)?.$2 == null || ctx.get(a.id)?.$2 == a ? a : reduce(ctx, ctx.get(a.id)!.$2!),
      App a => switch (reduce(ctx, a.fn)) {
          Fn(kind: Fn.Def, :var argID, result: var body) =>
            reduce(ctx, argID != null ? body.substExpr(argID, a.arg) : body),
          var fn => App(fn, reduce(ctx, a.arg)),
        },
      Fn a => Fn(a.kind, a.argID, reduce(ctx, a.argType), reduce(ctx, a.result)),
    };

Result<TypeCtx> assignable(TypeCtx ctx, Expr a, Expr b) {
  if (a.alphaEquiv(b)) return Success(ctx);
  switch ((a, b)) {
    case (Type, _):
      return Success(ctx);
    case (Fn a, Fn b) when a.kind == Fn.Typ && b.kind == Fn.Typ:
      final argCtx = assignable(ctx, b.argType, a.argType).wrap('''
args of:
${a.toString().indent}
${b.toString().indent}''');
      if (argCtx.isFailure) return argCtx;
      final retCtx = assignable(argCtx.success!, a.result, b.result).wrap('''
return types of:
${a.toString().indent}
${b.toString().indent}''');
      return retCtx.map((ctx) => a.argID == null ? ctx : ctx.without(a.argID!));
    case (Var a, Expr b):
      if (ctx.get(a.id) == null || ctx.get(a.id)!.$2 == null) {
        return Success(ctx.add(a.id, (Type, b)));
      } else {
        return assignable(ctx, ctx.get(a.id)!.$2!, b);
      }
    case (App a, App b):
      final fnCtx = assignable(ctx, a.fn, b.fn).wrap('''
fns of:
${a.toString().indent}
${b.toString().indent}''');
      if (fnCtx.isFailure) return fnCtx;
      return assignable(fnCtx.success!, a.arg, b.arg);
    case _:
      return Failure('not assignable:\n  $a\n  $b');
  }
}

// Evaluation

class Closure {
  final EvalCtx ctx;
  final ID? argID;
  final Expr body;

  Closure(this.ctx, this.argID, this.body);

  @override
  String toString() => 'Closure($ctx, $argID, $body)';

  @override
  bool operator ==(Object other) =>
      other is Closure &&
      argID == other.argID &&
      body.alphaEquiv(other.body) &&
      ctx.equals(other.ctx);

  @override
  int get hashCode {
    final sortedKeys = SplayTreeSet.of(ctx.keys);
    return Hash.all([
      argID.hashCode,
      body.hashCode,
      ...sortedKeys.map((k) => k.hashCode),
      ...sortedKeys.map((k) => ctx.get(k)!.hashCode)
    ]);
  }
}

sealed class TypeValue {
  const TypeValue();
}

class TypeType extends TypeValue {
  const TypeType._();
}

const type = TypeType._();

class FnTypeType extends TypeValue {
  final TypeValue argType;
  final TypeValue returnType;

  const FnTypeType(this.argType, this.returnType);
}

final EvalCtx coreEvalCtx = {Type.id: type};
final TypeCtx coreTypeCtx = {Type.id: (Type, Type)};

Object eval(EvalCtx ctx, Expr expr) {
  switch (expr) {
    case Var():
      return ctx.get(expr.id) ?? (throw Exception('$ctx: ${expr.id}'));
    case App():
      final fn = eval(ctx, expr.fn);
      final arg = eval(ctx, expr.arg);
      return switch (fn) {
        Closure(:var argID, :var ctx, :var body) =>
          eval(argID != null ? ctx.add(argID, arg) : ctx, body),
        Object Function(EvalCtx, Object) dartFn => dartFn(ctx, arg),
        _ => throw Exception('unknown fn object, type: ${fn.runtimeType}, value: $fn'),
      };
    case Fn(kind: Fn.Def):
      return Closure(
        ctx.restrict((expr.result).freeVars.difference({expr.argID})),
        expr.argID,
        expr.result,
      );
    case Fn(kind: Fn.Typ):
      final argType = eval(ctx, expr.argType) as TypeValue;
      return FnTypeType(
        argType,
        eval(expr.argID != null ? ctx.add(expr.argID!, argType) : ctx, expr.result) as TypeValue,
      );
  }
}

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
