typedef ID = String;

abstract class Serializable {
  const Serializable();

  String get serialize;
}

class Parser<T> {
  final ParseResult<T> Function(String) parse;

  const Parser(this.parse);

  Parser.lit(T result, String lit)
      : parse = ((str) => str.startsWith(lit)
            ? ParseSuccess(result, str.substring(lit.length))
            : ParseFailure('could not match $lit against $str'));

  static Parser<T> litThen<T>(String lit, Parser<T> andThen) =>
      Parser.lit(null, lit).andThen((_) => andThen);

  Parser<T> skip(String lit) => andThen((t) => Parser.lit(t, lit));

  static Parser<String> until(String stop) => Parser((str) {
        final index = str.indexOf(stop);
        return ParseSuccess(str.substring(0, index), str.substring(index + stop.length));
      });

  Parser.tryEach(List<Parser<T>> parsers)
      : parse = ((str) {
          final reasons = <String>[];
          final eachTried = parsers.fold<ParseResult<T>>(
            ParseFailure<T>(''),
            (prevResult, parser) => prevResult.cases(
              ok: (_) => prevResult,
              fail: (fail) {
                reasons.add(fail.reason);
                return parser.parse(str);
              },
            ),
          );
          return eachTried.cases(
            ok: (_) => eachTried,
            fail: (fail) {
              reasons.add(fail.reason);
              return ParseFailure(reasons.toString());
            },
          );
        });

  Parser<T2> andThen<T2>(Parser<T2> Function(T) parser) => Parser((str) {
        return parse(str).cases(
            ok: (ok) {
              return parser(ok.result).parse(ok.rest);
            },
            fail: (fail) => ParseFailure(fail.reason));
      });

  Parser<T2> map<T2>(T2 Function(T) f) => Parser((str) => parse(str).map(f));

  static Parser<Object> value(Type type) {
    if (type is TypeType) return Type.parser;
    throw Exception('don\'t know how to parse value of type $type');
  }
}

abstract class ParseResult<T> {
  const ParseResult();

  bool get isOk => this is ParseSuccess;

  R cases<R>({required R Function(ParseSuccess<T>) ok, required R Function(ParseFailure<T>) fail});
  ParseResult<T2> map<T2>(T2 Function(T) f) => cases(
      ok: (ok) => ParseSuccess(f(ok.result), ok.rest), fail: (fail) => ParseFailure(fail.reason));
}

class ParseSuccess<T> extends ParseResult<T> {
  final T result;
  final String rest;

  const ParseSuccess(this.result, this.rest);

  @override
  R cases<R>(
          {required R Function(ParseSuccess<T> p1) ok,
          required R Function(ParseFailure<T> p1) fail}) =>
      ok(this);
}

class ParseFailure<T> extends ParseResult<T> {
  final String reason;

  const ParseFailure(this.reason);

  @override
  R cases<R>(
          {required R Function(ParseSuccess<T> p1) ok,
          required R Function(ParseFailure<T> p1) fail}) =>
      fail(this);
}

abstract class Macro {}

abstract class Type extends Serializable {
  const Type();

  static const Type type = TypeType._();
  static const Expr expr = Literal(type, type);

  @override
  String get serialize {
    final type = this;
    if (type is TypeType) {
      return 'Type';
    } else if (type is FnType) {
      return 'FnType(${type.argType.serialize}, ${type.returnType.serialize})';
    } else if (type is ForeignType) {
      return 'ForeignType(${type.id})';
    } else {
      throw Exception('unknown type type ${type.runtimeType}');
    }
  }

  static final Parser<Type> parser = Parser.tryEach([
    Parser.lit(Type.type, 'Type'),
    Parser.litThen('FnType(', Type.parser).andThen((type) => Parser.litThen(', ', Type.parser)
        .andThen((retType) => Parser.lit(FnType(type, retType), ')'))),
    Parser.litThen('ForeignType(', Parser.until(')')).map(ForeignType.new),
  ]);

  @override
  String toString() => serialize;
}

class TypeType extends Type {
  const TypeType._();

  @override
  String toString() => 'Type';
}

class FnType extends Type {
  final Type argType;
  final Type returnType;

  const FnType(this.argType, this.returnType);

  @override
  bool operator ==(Object other) =>
      other is FnType && other.argType == argType && other.returnType == returnType;

  @override
  int get hashCode => Object.hash(argType, returnType);
}

class ForeignType extends Type {
  final ID id;

  const ForeignType(this.id);

  @override
  bool operator ==(Object other) => other is ForeignType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

abstract class Expr extends Serializable {
  const Expr();

  @override
  String toString() => serialize;

  @override
  String get serialize {
    final expr = this;
    if (expr is Placeholder) {
      return 'Placeholder';
    } else if (expr is Literal) {
      return 'Literal(${expr.type.serialize}, ${expr.val.serialize})';
    } else if (expr is Var) {
      return 'Var(${expr.id})';
    } else if (expr is FnApp) {
      return 'FnApp(${expr.fn.serialize}, ${expr.arg.serialize})';
    } else if (expr is FnDef) {
      return 'FnDef(${expr.argID}, ${expr.argType.serialize}, ${expr.returnType.serialize}, ${expr.body.serialize})';
    } else if (expr is FnTypeExpr) {
      return 'FnTypeExpr(${expr.argID}, ${expr.argType.serialize}, ${expr.returnType.serialize})';
    } else {
      throw Exception('unknown expr type ${expr.runtimeType}');
    }
  }

  static Parser<Expr> parser = Parser.tryEach([
    Parser.lit(Placeholder.expr, 'Placeholder'),
    Parser.litThen('Literal(', Type.parser).andThen(
      (type) => Parser.litThen(', ', Parser.value(type).skip(')').map((obj) => Literal(type, obj))),
    ),
    Parser.litThen('Var(', Parser.until(')')).map(Var.new),
    Parser.litThen('FnApp(', Expr.parser)
        .andThen((fn) => Parser.litThen(', ', Expr.parser).skip(')').map((arg) => FnApp(fn, arg))),
    Parser.litThen('FnDef(', Parser.until(',')).andThen((argID) => Expr.parser.andThen((argType) =>
        Parser.lit(null, ', ').andThen((_) => Expr.parser).andThen((returnType) =>
            Parser.lit(null, ', ')
                .andThen((_) => Expr.parser)
                .andThen((body) => Parser.lit(FnDef(argID, argType, returnType, body), ')'))))),
    Parser.lit(null, 'FnTypeExpr(').andThen((_) => Parser.until(',')).andThen((argID) =>
        Parser.lit(null, ', ').andThen((_) => Expr.parser).andThen((argType) =>
            Parser.lit(null, ', ')
                .andThen((_) => Expr.parser)
                .andThen((returnType) => Parser.lit(FnTypeExpr(argID, argType, returnType), ')')))),
  ]);
}

class Placeholder extends Expr {
  const Placeholder();

  static const expr = Placeholder();
}

class Literal extends Expr {
  final Type type;
  final Object val;

  const Literal(this.type, this.val);

  @override
  bool operator ==(Object other) => other is Literal && type == other.type && val == other.val;

  @override
  int get hashCode => Object.hash(type, val);
}

class Var extends Expr {
  final ID id;

  const Var(this.id);

  @override
  bool operator ==(Object other) => other is Var && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class FnApp extends Expr {
  final Expr fn;
  final Expr arg;

  const FnApp(this.fn, this.arg);

  static Expr chain(Expr fn, Iterable<Expr> args) => args.fold(fn, FnApp.new);
}

class FnDef extends Expr {
  final ID argID;
  final Expr argType;
  final Expr returnType;
  final Expr body;

  const FnDef(this.argID, this.argType, this.returnType, this.body);

  static Expr chain(Expr returnType, Iterable<MapEntry<ID, Expr>> args, Expr body) => args
      .toList()
      .reversed
      .fold(
        MapEntry(returnType, body),
        (fn, arg) => MapEntry(
          FnDef(arg.key, arg.value, fn.key, fn.value),
          FnTypeExpr(arg.key, arg.value, fn.key),
        ),
      )
      .value;
}

class FnTypeExpr extends Expr {
  final ID argID;
  final Expr argType;
  final Expr returnType;

  const FnTypeExpr(this.argID, this.argType, this.returnType);

  static Expr chain(Iterable<MapEntry<ID, Expr>> args, Expr returnType) =>
      args.toList().reversed.fold(returnType, (ret, arg) => FnTypeExpr(arg.key, arg.value, ret));
}

class BindingCtx {
  final Map<ID, Object> values;

  const BindingCtx._(this.values);
  const BindingCtx.from(this.values);
  static const empty = BindingCtx._({});

  Object operator [](ID id) => values[id]!;
  BindingCtx add(ID id, Object value) => BindingCtx._({...values, id: value});
  BindingCtx restrict(Iterable<ID> to) => BindingCtx._({for (final v in to) v: this[v]});
}

class TypeCtx {
  final Map<ID, Expr> types;
  final Map<ID, Expr> values;

  const TypeCtx._(this.types, this.values);
  static const empty = TypeCtx._({}, {});

  Expr? getType(ID id) => types[id];
  Expr? getValue(ID id) => values[id];
  TypeCtx addType(ID id, Expr type) => TypeCtx._({...types, id: type}, values);
  TypeCtx addValue(ID id, Expr value) => TypeCtx._(types, {...values, id: value});
  TypeCtx addTypeValue(ID id, Expr type, Expr? value) =>
      (value == null ? this : addValue(id, value)).addType(id, type);

  @override
  String toString() => 'TypeCtx(types: $types, values: $values)';
}

class Closure {
  final BindingCtx ctx;
  final ID argID;
  final Expr body;

  Closure(this.ctx, this.argID, this.body);
}

abstract class TypeCheckResult {
  const TypeCheckResult();

  bool get isOk;
  TypeCheckSuccess get assertOk {
    if (this is TypeCheckSuccess) return this as TypeCheckSuccess;
    throw Exception((this as TypeCheckFailure).reason);
  }

  TypeCheckFailure get assertFailure => this as TypeCheckFailure;

  TypeCheckResult map(TypeCheckResult Function(Expr, Expr) fn);

  TypeCheckResult expect(TypeCtx ctx, Expr expected, TypeCheckResult Function(Expr, Expr) fn) {
    return map((type, redex) {
      if (assignable(ctx, expected, type) == null) {
        return TypeCheckFailure('expected type $expected did not match $type');
      }
      return fn(type, redex);
    });
  }
}

class TypeCheckSuccess extends TypeCheckResult {
  final Expr type;
  final Expr redex;

  TypeCheckSuccess(this.type, this.redex);

  @override
  bool get isOk => true;

  @override
  TypeCheckResult map(TypeCheckResult Function(Expr, Expr) fn) => fn(type, redex);
}

class TypeCheckFailure extends TypeCheckResult {
  String reason;

  TypeCheckFailure(this.reason);

  @override
  bool get isOk => false;

  @override
  TypeCheckResult map(TypeCheckResult Function(Expr, Expr) fn) => this;
}

TypeCheckResult typeCheck(TypeCtx ctx, Expr expr) {
  if (expr is Var) {
    final type = ctx.getType(expr.id);
    if (type == null) {
      return TypeCheckFailure('unknown var ${expr.id}, ctx is $ctx');
    }
    return TypeCheckSuccess(type, ctx.getValue(expr.id) ?? expr);
  } else if (expr is Literal) {
    return TypeCheckSuccess(Literal(Type.type, expr.type), expr);
  } else if (expr is FnApp) {
    late final TypeCheckResult fnTypeResult;
    fnTypeResult = typeCheck(ctx, expr.fn);
    return fnTypeResult.map((fnType, fn) {
      late final FnTypeExpr fnTypeExpr;
      if (fnType is Literal && fnType.type == Type.type && fnType.val is FnType) {
        fnTypeExpr = FnTypeExpr(
          '_',
          Literal(Type.type, (fnType.val as FnType).argType),
          Literal(Type.type, (fnType.val as FnType).returnType),
        );
      } else if (fnType is FnTypeExpr) {
        fnTypeExpr = fnType;
      } else {
        return TypeCheckFailure('tried to apply non fn $fn of type $fnType');
      }
      return typeCheck(ctx, expr.arg).expect(ctx, fnTypeExpr.argType, (argType, arg) {
        late final Expr redex;
        if (fn is Literal) {
          if (arg is! Literal) {
            redex = expr;
          } else {
            redex = Literal(
              (fn.type as FnType).returnType,
              eval(BindingCtx.empty, FnApp(fn, arg)),
            );
          }
        } else if (fn is FnDef) {
          redex = typeCheck(ctx.addTypeValue(fn.argID, fnTypeExpr.argType, arg), fn.body)
              .assertOk
              .redex;
        } else {
          redex = expr;
        }
        return TypeCheckSuccess(fnTypeExpr.returnType, redex);
      });
    });
  } else if (expr is FnDef) {
    return typeCheck(ctx, expr.argType).expect(ctx, Type.expr, (_, argType) {
      ctx = ctx.addType(expr.argID, argType);
      return typeCheck(ctx, expr.returnType).expect(ctx, Type.expr, (_, returnType) {
        return typeCheck(ctx, expr.body).expect(ctx, returnType, (bodyType, body) {
          return reduceFnDef(ctx, FnDef(expr.argID, argType, returnType, body));
        });
      });
    });
  } else if (expr is FnTypeExpr) {
    return typeCheck(ctx, expr.argType).expect(ctx, Type.expr, (_, argType) {
      ctx = ctx.addType(expr.argID, argType);
      return typeCheck(ctx, expr.returnType).expect(ctx, Type.expr, (_, returnType) {
        return TypeCheckSuccess(
          Type.expr,
          (argType is Literal && returnType is Literal)
              ? Literal(Type.type, FnType(argType.val as Type, returnType.val as Type))
              : FnTypeExpr(expr.argID, argType, returnType),
        );
      });
    });
  } else if (expr is Placeholder) {
    return TypeCheckFailure('placeholder needs to be filled in');
  } else {
    throw Exception('unknown typeCheck expr type ${expr.runtimeType}');
  }
}

TypeCheckResult reduceFnDef(TypeCtx ctx, FnDef def) {
  final type = (def.argType is Literal && def.returnType is Literal)
      ? Literal(Type.type,
          FnType((def.argType as Literal).val as Type, (def.returnType as Literal).val as Type))
      : FnTypeExpr(def.argID, def.argType, def.returnType);
  final bindings = {for (final id in freeVars(def)) id: ctx.getValue(id)};
  if (type is! Literal || bindings.values.any((b) => b is! Literal)) {
    return TypeCheckSuccess(type, def);
  } else {
    return TypeCheckSuccess(
      type,
      Literal(
        type.val as Type,
        Closure(
          BindingCtx.from(bindings.map((key, value) => MapEntry(key, (value as Literal).val))),
          def.argID,
          def.body,
        ),
      ),
    );
  }
}

const Expr macroTypeDef = FnDef(
  'MacroType',
  Literal(Type.type, Type.type),
  Literal(Type.type, Type.type),
  FnTypeExpr('_', Var('MacroType'), Literal(Type.type, exprType)),
);
const exprType = ForeignType('Expr');

Object eval(BindingCtx ctx, Expr expr) {
  if (expr is Var) {
    return ctx[expr.id];
  } else if (expr is Literal) {
    return expr.val;
  } else if (expr is FnApp) {
    final fn = eval(ctx, expr.fn) as Closure;
    final arg = eval(ctx, expr.arg);
    return eval(fn.ctx.add(fn.argID, arg), fn.body);
  } else if (expr is FnDef) {
    return Closure(ctx.restrict(freeVars(expr)), expr.argID, expr.body);
  } else if (expr is FnTypeExpr) {
    return FnType(eval(ctx, expr.argType) as Type, eval(ctx, expr.returnType) as Type);
  } else {
    throw Exception('unknown eval expr type ${expr.runtimeType}');
  }
}

TypeCtx? assignable(TypeCtx ctx, Expr to, Expr from) {
  if (to == from) {
    return ctx;
  } else if (to is Var) {
    final toRedex = ctx.getValue(to.id);
    if (toRedex != null) {
      return assignable(ctx, toRedex, from);
    }
    if (from is Var) {
      final fromRedex = ctx.getValue(from.id);
      if (fromRedex != null) {
        return assignable(ctx, to, fromRedex);
      }
    }
    if (occurs(ctx, to.id, from)) return null;
    return ctx.addValue(to.id, from);
  } else if (to is Literal) {
    return to == from ? ctx : null;
  } else if (to is FnTypeExpr) {
    if (from is! FnTypeExpr) return null;
    final argTypeCtx = assignable(ctx, from.argType, to.argType);
    if (argTypeCtx == null) return null;
    ctx = argTypeCtx.addType(to.argID, to.argType);
    return assignable(ctx, to.returnType, varSubst(from.returnType, from.argID, to.argID));
  } else {
    return null;
  }
}

Expr varSubst(Expr expr, ID from, ID to) {
  if (expr is Var) {
    return Var(expr.id == from ? to : expr.id);
  } else if (expr is FnDef) {
    return expr.argID == from || expr.argID == to
        ? expr
        : FnDef(
            expr.argID,
            varSubst(expr.argType, from, to),
            varSubst(expr.returnType, from, to),
            varSubst(expr.body, from, to),
          );
  } else if (expr is FnTypeExpr) {
    return expr.argID == from || expr.argID == to
        ? expr
        : FnTypeExpr(
            expr.argID,
            varSubst(expr.argType, from, to),
            varSubst(expr.returnType, from, to),
          );
  } else if (expr is FnApp) {
    return FnApp(varSubst(expr.fn, from, to), varSubst(expr.arg, from, to));
  } else {
    return expr;
  }
}

bool occurs(TypeCtx ctx, ID id, Expr expr) {
  if (expr is Literal) return false;
  if (expr is Var) return expr.id == id;
  if (expr is FnApp) return occurs(ctx, id, expr.arg) || occurs(ctx, id, expr.fn);
  if (expr is FnDef) {
    return occurs(ctx, id, expr.argType) ||
        (expr.argID != id && (occurs(ctx, id, expr.returnType) || occurs(ctx, id, expr.body)));
  }
  if (expr is FnTypeExpr) {
    return occurs(ctx, id, expr.argType) || (expr.argID != id && occurs(ctx, id, expr.returnType));
  }
  throw UnimplementedError('occurs for expr type ${expr.runtimeType}');
}

Set<ID> freeVars(Expr expr) {
  if (expr is Var) {
    return {expr.id};
  } else if (expr is Literal) {
    return {};
  } else if (expr is FnApp) {
    return freeVars(expr.arg).union(freeVars(expr.fn));
  } else if (expr is FnDef) {
    return freeVars(expr.returnType)
        .union(freeVars(expr.body))
        .difference({expr.argID}).union(freeVars(expr.argType));
  } else if (expr is FnTypeExpr) {
    return freeVars(expr.returnType).difference({expr.argID}).union(freeVars(expr.argType));
  } else {
    throw Exception('unknown freeVars expr type ${expr.runtimeType}');
  }
}

extension on Object {
  String get serialize {
    final obj = this;
    if (obj is Serializable) obj.serialize;
    return obj.toString();
  }
}
