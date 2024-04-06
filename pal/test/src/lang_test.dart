import 'dart:io';

import 'package:pal/src/eval.dart';
import 'package:pal/src/lang.dart';
import 'package:pal/src/parse.dart';
import 'package:pal/src/serialize.dart';
import 'package:test/test.dart';

const letForEval = '''
  (let: (T: Type, V: Type, V, (V)[T])[T]) {
    let(Type, Type, Type, (d: Type){d})
  }((T: Type, V: Type, var: V, fn: (V)[T]){
    fn(var)
  })
''';

const isSuccess = IsSuccess();

class IsSuccess extends Matcher {
  const IsSuccess();

  @override
  Description describe(Description description) => StringDescription('Expected Success');

  @override
  bool matches(item, Map<dynamic, dynamic> matchState) => item is Progress;

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) =>
      StringDescription('message: ${(item as Failure).reason}');
}

void main() {
  test('parsing and serializing', () {
    const programs = {
      // 'a': Var('a'),
      'a(b)': App(false, Var('a'), Var('b')),
      'a(b(c))': App(false, Var('a'), App(false, Var('b'), Var('c'))),
      'a(b, c)': App(false, App(false, Var('a'), Var('b')), Var('c')),
      'a(b(c, d), e)': App(false,
          App(false, Var('a'), App(false, App(false, Var('b'), Var('c')), Var('d'))), Var('e')),
      'a<b>(c)': App(false, App(true, Var('a'), Var('b')), Var('c')),
      '<A: Type>(a: A){a}':
          Fn(true, Fn.Def, 'A', Var('Type'), Fn(false, Fn.Def, 'a', Var('A'), Var('a'))),
      '(f: (Type, Type)[Type], a: Type) { f(a, a) }': Fn(
        false,
        Fn.Def,
        'f',
        Fn(false, Fn.Typ, null, Var('Type'), Fn(false, Fn.Typ, null, Var('Type'), Var('Type'))),
        Fn(false, Fn.Def, 'a', Var('Type'), App(false, App(false, Var('f'), Var('a')), Var('a'))),
      ),
      '(f: (_, Type)[Type], a: Type) { _(a, _) }': Fn(
        false,
        Fn.Def,
        'f',
        Fn(false, Fn.Typ, null, Var('_0'), Fn(false, Fn.Typ, null, Var('Type'), Var('Type'))),
        Fn(false, Fn.Def, 'a', Var('Type'), App(false, App(false, Var('_1'), Var('a')), Var('_2'))),
      ),
    };
    for (final MapEntry(key: program, value: parsed) in programs.entries) {
      expect(parseExpr(tokenize(program)).$1, equals(parsed));
      expect(parseExpr(tokenize(program)).$1.toString(), equals(program));
    }
  });

  test('let check', () {
    final result = check(coreTypeCtx, Type, parseExpr(tokenize(letForEval)).$1);
    expect(result, isSuccess);
    var Progress(result: Jdg(:type, :value), :gotMore) = result as Progress<Jdg>;
    expect(gotMore, true);
    expect(type, Type);
    expect(value, Type);
  });

  test('let eval', () {
    expect(eval(coreEvalCtx, parseExpr(tokenize(letForEval)).$1), type);
  });

  test('compile exprs', () {
    final exprs = parseProgram(tokenize(File('lib/src/core.pal').readAsStringSync())).$1;
    var typeCtx = coreTypeCtx;
    var evalCtx = coreEvalCtx;
    for (final module in exprs) {
      TypeCtx extModuleTypeCtx = IDMap.empty();
      TypeCtx moduleTypeCtx = IDMap.empty();
      for (final binding in module) {
        print(binding.id);
        Expr? expectedType;
        if (binding.type != null) {
          final typeResult = check(typeCtx.union(moduleTypeCtx), Type, binding.type!);
          expect(typeResult, isSuccess, reason: 'typing type of ${binding.id}:\n  ${binding.type}');
          Progress(result: Jdg(value: expectedType)) = typeResult as Progress<Jdg>;
          print(expectedType.toString().indent);
        }
        late final Object? value;
        if (binding.value != null) {
          final checkResult = check(typeCtx.union(moduleTypeCtx), expectedType, binding.value!);
          expect(checkResult, isSuccess,
              reason: 'typing expr of ${binding.id}:\n  ${binding.value}');
          final Progress(result: Jdg(:type, value: redex)) = checkResult as Progress<Jdg>;
          expect(typeCtx.union(moduleTypeCtx), isNot(contains(binding.id)));
          print(type.toString().indent);
          print(redex.toString().indent);
          extModuleTypeCtx = extModuleTypeCtx.add(binding.id, Ann(binding.type ?? type, null));
          moduleTypeCtx = moduleTypeCtx.add(binding.id, Ann(type, redex));
          value = eval(evalCtx, binding.value!);
        } else {
          extModuleTypeCtx = extModuleTypeCtx.add(binding.id, Ann(binding.type!, null));
          moduleTypeCtx = moduleTypeCtx.add(binding.id, Ann(expectedType, null));
          value = null;
        }
        expect(evalCtx, isNot(contains(binding.id)));
        evalCtx = evalCtx.add(binding.id, value);
      }
      typeCtx = typeCtx.union(extModuleTypeCtx);
    }
  });
}
