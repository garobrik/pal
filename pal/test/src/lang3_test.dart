import 'package:pal/src/lang3.dart';
import 'package:pal/src/lang3src.dart';
import 'package:test/test.dart';

const letForEval = '''
  (FnDef(let)(FnType(T)(Type)(FnType(V)(Type)(FnType(_)(V)(FnType(_)(FnType(_)(V)(T))(T)))))(
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

void main() {
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
    expect(result.isFailure, isFalse);
    expect(result.success!.$1, coreTypeCtx);
    expect(result.success!.$2, Type);
    expect(result.success!.$3, Type);
  });

  test('let eval', () {
    expect(eval(coreEvalCtx, Expr.parse(letForEval).$1), type);
  });

  test('compile exprs', () {
    var typeCtx = coreTypeCtx;
    var evalCtx = coreEvalCtx;
    for (final binding in exprs) {
      final (expr, _) = Expr.parse(binding.source);
      final checkResult = check(typeCtx, null, expr);
      expect(checkResult.isFailure, isFalse);
      final (_, type, redex) = checkResult.success!;
      expect(typeCtx, isNot(contains(binding.id)));
      typeCtx[binding.id] = (type, redex);
      final evald = eval(evalCtx, expr);
      expect(evalCtx, isNot(contains(binding.id)));
      evalCtx[binding.id] = evald;
    }
  });
}
