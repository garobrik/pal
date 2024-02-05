import 'package:pal/src/lang3.dart';
import 'package:pal/src/lang3src.dart';
import 'package:test/test.dart';

const letForEval = '''
  FnDef(let)(FnType(T)(Type)(FnType(V)(Type)(FnType(_)(V)(FnType(_)(FnType(_)(V)(T))(T)))))(
    let(Type)(Type)(Type)(FnDef(d)(Type)(d))
  )(
    FnDef(T)(Type)(
      FnDef(V)(Type)(
        FnDef(var)(V)(
          FnDef(fn)(FnType(_)(V)(T))(
            fn(var)
          )
        )
      )
    )
  )
''';

const letBool = '''
  FnDef(let)(FnType(B)(Type)(FnType(T)(Type)(FnType(y)(T)(FnType(f)(FnType(_)(T)(B)))(B))))(
    let(Type)(Type)(FnType(R)(Type)(FnType(t)(R)(FnType(f)(R)(R))))(FnDef(Bool)(Type)(
      let(Type)(Bool)(FnDef(R)(Type)(FnDef(t)(R)(FnDef(f)(R)(t))))(FnDef(true)(Bool)(
        let(Type)(Bool)(FnDef(R)(Type)(FnDef(t)(R)(FnDef(f)(R)(f))))(FnDef(false)(Bool)(
          let(Type)(FnType(R)(Type)(FnType(_)(Bool)(FnType(_)(R)(FnType(_)(R)(R)))))(FnDef(R)(Type)(FnDef(b)(Bool)(FnDef(t)(R)(FnDef(f)(R)(b(R)(t)(f))))))(FnDef(if)(FnType(R)(Type)(FnType(_)(Bool)(FnType(_)(R)(FnType(_)(R)(R)))))(
            if(Type)(true)(Type)(FnType(_)(Type)(Type)) 
          ))
        ))
      ))
    ))
    FnApp(FnApp(FnApp(FnApp(Var(letIn), Literal(Type, Type)), Literal(Type, Type)), FnTypeExpr(T, Literal(Type, Type), FnTypeExpr(_, Var(T), FnTypeExpr(_, Var(T), Var(T))))), FnDef(Bool, Literal(Type, Type), Literal(Type, Type), FnApp(FnApp(FnApp(FnApp(Var(letIn), Literal(Type, Type)), Var(Bool)), FnDef(T, Literal(Type, Type), FnTypeExpr(_, Var(T), FnTypeExpr(_, Var(T), Var(T))), FnDef(a, Var(T), FnTypeExpr(_, Var(T), Var(T)), FnDef(b, Var(T), Var(T), Var(a))))), FnDef(true, Var(Bool), Literal(Type, Type), FnApp(FnApp(FnApp(FnApp(Var(letIn), Literal(Type, Type)), Var(Bool)), FnDef(T, Literal(Type, Type), FnTypeExpr(_, Var(T), FnTypeExpr(_, Var(T), Var(T))), FnDef(a, Var(T), FnTypeExpr(_, Var(T), Var(T)), FnDef(b, Var(T), Var(T), Var(b))))), FnDef(false, Var(Bool), Literal(Type, Type), FnApp(FnApp(FnApp(FnApp(Var(letIn), Literal(Type, Type)), FnTypeExpr(T, Literal(Type, Type), FnTypeExpr(_, Var(Bool), FnTypeExpr(_, Var(T), FnTypeExpr(_, Var(T), Var(T)))))), FnDef(T, Literal(Type, Type), FnTypeExpr(_, Var(Bool), FnTypeExpr(_, Var(T), FnTypeExpr(_, Var(T), Var(T)))), FnDef(c, Var(Bool), FnTypeExpr(_, Var(T), FnTypeExpr(_, Var(T), Var(T))), FnDef(a, Var(T), FnTypeExpr(_, Var(T), Var(T)), FnDef(b, Var(T), Var(T), FnApp(FnApp(FnApp(Var(c), Var(T)), Var(a)), Var(b))))))), FnDef(if, FnTypeExpr(T, Placeholder, FnTypeExpr(c, Var(Bool), FnTypeExpr(a, Var(T), FnTypeExpr(b, Var(T), Var(T))))), Literal(Type, Type), FnApp(FnApp(FnApp(FnApp(Var(if), Literal(Type, Type)), Var(false)), Literal(Type, Type)), FnTypeExpr(_, Literal(Type, Type), Literal(Type, Type)))))))))))
  )(
    FnDef(B, Literal(Type, Type), FnTypeExpr(T, Literal(Type, Type), FnTypeExpr(y, Var(T), FnTypeExpr(f, FnTypeExpr(_, Var(T), Var(B)), Var(B)))), FnDef(T, Literal(Type, Type), FnTypeExpr(y, Var(T), FnTypeExpr(f, FnTypeExpr(_, Var(T), Var(B)), Var(B))), FnDef(y, Var(T), FnTypeExpr(f, FnTypeExpr(_, Var(T), Var(B)), Var(B)), FnDef(f, FnTypeExpr(_, Var(T), Var(B)), Var(B), FnApp(Var(f), Var(y))))))
  )
''';

const isSuccess = IsSuccess();

class IsSuccess extends Matcher {
  const IsSuccess();

  @override
  Description describe(Description description) => StringDescription('Expected Success');

  @override
  bool matches(item, Map<dynamic, dynamic> matchState) => item is Success;

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) =>
      StringDescription('message: ${(item as Failure).msg}');
}

void main() {
  test('freshen', () {
    const ids = {
      'R': 'R1',
      'R1': 'R2',
      'R9': 'R10',
      'R10': 'R11',
    };
    for (final MapEntry(key: id, value: freshenedID) in ids.entries) {
      expect(id.freshen, equals(freshenedID));
    }
  });

  test('simple parsing and serializing', () {
    const programs = {
      'a': Var('a'),
      'a(b)': FnApp(Var('a'), Var('b')),
      'a(b(c))': FnApp(Var('a'), FnApp(Var('b'), Var('c'))),
      'a(b)(c)': FnApp(FnApp(Var('a'), Var('b')), Var('c')),
      'a(b(c)(d))(e)': FnApp(FnApp(Var('a'), FnApp(FnApp(Var('b'), Var('c')), Var('d'))), Var('e')),
      'FnDef(A)(Type)(FnDef(a)(A)(a))': FnDef('A', Var('Type'), FnDef('a', Var('A'), Var('a'))),
    };
    for (final MapEntry(key: program, value: parsed) in programs.entries) {
      expect(Expr.parse(program).$1, equals(parsed));
      expect(Expr.parse(program).$1.toString(), equals(program));
    }
  });

  test('parsing whitespace', () {
    const programs = {
      '  a   \n': Var('a'),
      'a(\n b  ) ': FnApp(Var('a'), Var('b')),
      'a(\nb( \n c))': FnApp(Var('a'), FnApp(Var('b'), Var('c'))),
      '  a( \n  b)(c  )': FnApp(FnApp(Var('a'), Var('b')), Var('c')),
      '  a(b(c  )(d)  \n )( e)  ':
          FnApp(FnApp(Var('a'), FnApp(FnApp(Var('b'), Var('c')), Var('d'))), Var('e')),
    };
    for (final MapEntry(key: program, value: parsed) in programs.entries) {
      expect(Expr.parse(program).$1, equals(parsed));
    }
  });

  test('let check', () {
    final result = check(coreTypeCtx, Type, Expr.parse(letForEval).$1);
    expect(result, isSuccess);
    expect(result.success!.$1, coreTypeCtx);
    expect(result.success!.$2, Type);
    expect(result.success!.$3, Type);
  });

  test('let eval', () {
    expect(eval(coreEvalCtx, Expr.parse(letForEval).$1), type);
  });

  test('letBool check', () {
    final result = check(coreTypeCtx, Type, Expr.parse(letForEval).$1);
    expect(result, isSuccess);
    expect(result.success!.$1, coreTypeCtx);
    expect(result.success!.$2, Type);
    expect(result.success!.$3, Type);
  });

  test('letBool eval', () {
    expect(eval(coreEvalCtx, Expr.parse(letForEval).$1), type);
  });

  test('compile exprs', () {
    var typeCtx = coreTypeCtx;
    var evalCtx = coreEvalCtx;
    for (final module in exprs) {
      TypeCtx extModuleTypeCtx = {};
      TypeCtx moduleTypeCtx = {};
      for (final binding in module) {
        late final Expr? origExpectedType;
        late final Expr? expectedType;
        if (binding.typeSource == null) {
          origExpectedType = null;
          expectedType = null;
        } else {
          (origExpectedType, _) = Expr.parse(binding.typeSource!);
          final typeResult = check(typeCtx.union(extModuleTypeCtx), Type, origExpectedType);
          expect(typeResult, isSuccess,
              reason: 'typing type of ${binding.id}:\n  $origExpectedType');
          (_, _, expectedType) = typeResult.success!;
        }
        late final Object? value;
        if (binding.valueSource != null) {
          final (expr, _) = Expr.parse(binding.valueSource!);
          final checkResult = check(typeCtx.union(moduleTypeCtx), expectedType, expr);
          expect(checkResult, isSuccess, reason: 'typing expr of ${binding.id}:\n  $expr');
          final (_, type, redex) = checkResult.success!;
          expect(typeCtx.union(moduleTypeCtx), isNot(contains(binding.id)));
          extModuleTypeCtx = extModuleTypeCtx.add(binding.id, (type, null));
          moduleTypeCtx = moduleTypeCtx.add(binding.id, (origExpectedType ?? type, redex));
          value = eval(evalCtx, expr);
        } else {
          value = null;
        }
        expect(evalCtx, isNot(contains(binding.id)));
        evalCtx = evalCtx.add(binding.id, value);
      }
      typeCtx = typeCtx.union(moduleTypeCtx);
    }
  });
}
