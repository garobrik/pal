import 'dart:io';

import 'package:pal/src/lang3.dart';
import 'package:test/test.dart';

const letForEval = '''
  (let: [T: Type, V: Type, V, [V]{T}]{T}) {
    let(Type, Type, Type, (d: Type){d})
  }((T: Type, V: Type, var: V, fn: [V]{T}){
    fn(var)
  })
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
      // 'a': Var('a'),
      'a(b)': App(Var('a'), Var('b')),
      'a(b(c))': App(Var('a'), App(Var('b'), Var('c'))),
      'a(b)(c)': App(App(Var('a'), Var('b')), Var('c')),
      'a(b, c)': App(App(Var('a'), Var('b')), Var('c')),
      'a(b(c)(d))(e)': App(App(Var('a'), App(App(Var('b'), Var('c')), Var('d'))), Var('e')),
      '<A: Type>(a: A){a}': Fn(Fn.Def, 'A', Var('Type'), Fn(Fn.Def, 'a', Var('A'), Var('a'))),
      ''' (f: [Type, Type]{Type}, a: Type) {
            f(a, a)
          }''': Fn(
        Fn.Def,
        'f',
        Fn(Fn.Typ, null, Var('Type'), Fn(Fn.Typ, null, Var('Type'), Var('Type'))),
        Fn(Fn.Def, 'a', Var('Type'), App(App(Var('f'), Var('a')), Var('a'))),
      ),
    };
    for (final MapEntry(key: program, value: parsed) in programs.entries) {
      expect(Expr.parse(tokenize(program)).$1, equals(parsed));
      // expect(Expr.parse(program).toString(), equals(program));
    }
  });

  test('let check', () {
    final result = check(coreTypeCtx, Type, Expr.parse(tokenize(letForEval)).$1);
    expect(result, isSuccess);
    expect(result.success!.$1, coreTypeCtx);
    expect(result.success!.$2, Type);
    expect(result.success!.$3, Type);
  });

  test('let eval', () {
    expect(eval(coreEvalCtx, Expr.parse(tokenize(letForEval)).$1), type);
  });

  test('compile exprs', () {
    final exprs = parseProgram(tokenize(File('lib/src/core.pal').readAsStringSync())).$1;
    var typeCtx = coreTypeCtx;
    var evalCtx = coreEvalCtx;
    for (final module in exprs) {
      TypeCtx extModuleTypeCtx = {};
      TypeCtx moduleTypeCtx = {};
      for (final binding in module) {
        late final Expr? expectedType;
        if (binding.type == null) {
          expectedType = null;
        } else {
          final typeResult = check(typeCtx.union(moduleTypeCtx), Type, binding.type!);
          expect(typeResult, isSuccess, reason: 'typing type of ${binding.id}:\n  ${binding.type}');
          (_, _, expectedType) = typeResult.success!;
        }
        late final Object? value;
        if (binding.value != null) {
          final checkResult = check(typeCtx.union(moduleTypeCtx), expectedType, binding.value!);
          expect(checkResult, isSuccess,
              reason: 'typing expr of ${binding.id}:\n  ${binding.value}');
          final (_, type, redex) = checkResult.success!;
          expect(typeCtx.union(moduleTypeCtx), isNot(contains(binding.id)));
          extModuleTypeCtx = extModuleTypeCtx.add(binding.id, (binding.type ?? type, null));
          moduleTypeCtx = moduleTypeCtx.add(binding.id, (type, redex));
          value = eval(evalCtx, binding.value!);
        } else {
          extModuleTypeCtx = extModuleTypeCtx.add(binding.id, (binding.type!, null));
          moduleTypeCtx = moduleTypeCtx.add(binding.id, (expectedType, null));
          value = null;
        }
        expect(evalCtx, isNot(contains(binding.id)));
        evalCtx = evalCtx.add(binding.id, value);
      }
      typeCtx = typeCtx.union(extModuleTypeCtx);
    }
  });
}
