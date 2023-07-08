import 'package:pal/src/lang2.dart';
import 'package:test/test.dart';

const letForEval = '''
  (FnDef(let)(FnType(T)(Type)(FnType(V)(Type)(FnType(_)(V)(FnType(_)(FnType(_)(V)(T))(T)))))(Type)(
    let(Type)(Type)(Type)(FnDef(d)(Type)(Type)(d))
  )(
    FnDef(T)(Type)(FnType(V)(Type)(FnType(_)(V)(FnType(_)(FnType(_)(V)(T))(T))))(
      FnDef(V)(Type)(FnType(_)(V)(FnType(_)(FnType(_)(V)(T))(T)))(
        FnDef(var)(V)(FnType(_)(FnType(_)(V)(T))(T))(
          FnDef(fn)(FnType(_)(V)(T))(T)(
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
      'FnDef(A)(Type)(A)(FnDef(a)(A)(A)(a))':
          FnDef('A', Var('Type'), Var('A'), FnDef('a', Var('A'), Var('A'), Var('a'))),
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
    final result = check(defaultTypeCtx, Type, Expr.parse(letForEval).$1);
    expect(result.isFailure, isFalse);
    expect(result.success!.$1, defaultTypeCtx);
    expect(result.success!.$2, Type);
    expect(result.success!.$3, Type);
  });

  test('let eval', () {
    expect(eval(defaultEvalCtx, Expr.parse(letForEval).$1), type);
  });
}
