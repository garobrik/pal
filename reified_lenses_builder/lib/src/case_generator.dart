import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';

void maybeGenerateCasesExtension(StringBuffer output, Class clazz) {
  final cases = clazz
      .getAnnotation(ReifiedLens)!
      .read('cases')
      .listValue
      .map((c) => Type.fromDartType(clazz.element!.library, c.toTypeValue()!));

  if (cases.isEmpty) return;

  final extension =
      Extension('${clazz.name}CasesExtension', Type('Cursor', args: [clazz]), params: clazz.params);
  extension.declare(output, (output) {
    _generateTypeGetter(output, clazz, cases);
    output.writeln();
    _generateCasesMethod(output, clazz, cases);
  });
}

void _generateTypeGetter(StringBuffer output, Class clazz, Iterable<Type> cases) {
  final param = Param(clazz, '_value');
  final typeGetter = Getter('type', Type('GetCursor', args: [Type.type]));
  final ifElsePart = ifElse(
    {for (final caze in cases) '${param.name} is $caze': 'return $caze;'},
    elseBody: 'throw Exception(\'${clazz.name} type cursor getter: unknown subtype\');',
  );
  output.writeln(
    typeGetter.declare(
      body: '''
        thenGet<Type>(Getter.field(\'type\', ($param) { $ifElsePart }))
  ''',
    ),
  );
}

void _generateCasesMethod(StringBuffer output, Class clazz, Iterable<Type> cases) {
  final typeParam = clazz.newTypeParams(1).first;
  final params = cases.map(
    (caze) => Param(
      FunctionType(returnType: typeParam, requiredArgs: [
        Type('Cursor', args: [caze])
      ]),
      _caseArgName(caze),
      isNamed: true,
      isRequired: true,
    ),
  );
  final casesMethod = Method(
    'cases',
    typeParams: [typeParam],
    returnType: typeParam,
    params: params,
  );

  casesMethod.declare(
    output,
    expression: false,
    body: switchCase(
      'type.get',
      {
        for (final caseParam in zip(cases, params))
          '${caseParam.first}': 'return ${caseParam.second.name}(this.cast<${caseParam.first}>());'
      },
      defaultBody: 'throw Exception(\'${clazz.name} cases cursor method: unkown subtype\');',
    ),
  );
}

String _caseArgName(Type caze) =>
    caze.toString().substring(0, 1).toLowerCase() + caze.toString().substring(1);
