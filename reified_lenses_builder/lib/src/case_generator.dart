import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';

void maybeGenerateCasesExtension(StringBuffer output, Class clazz) {
  final cases = clazz
      .getAnnotation(ReifiedLens)!
      .read('cases')
      .listValue
      .map((c) => Type.fromDartType(c.toTypeValue()!));

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
  final typeGetter = Getter('type', Type('GetCursor', args: [Type.type]));
  final ifElsePart = ifElse(
    {for (final caze in cases) 'this is $caze': 'return $caze;'},
    elseBody: 'throw Error();',
  );
  output.writeln(
    typeGetter.declare(
      body: '''
        thenGet<Type>(Getter.field("type", (_value) { $ifElsePart }))
  ''',
    ),
  );
}

void _generateCasesMethod(StringBuffer output, Class clazz, Iterable<Type> cases) {
  final typeParam = clazz.newTypeParams(1).first;
  final params = cases.map(
    (caze) => Param(
      Type('Cursor', args: [caze]),
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

  output.writeln(
    casesMethod.declare(
      expression: false,
      body: switchCase(
        'type.get',
        {
          for (final caseParam in zip(cases, params))
            '${caseParam.first}':
                'return ${caseParam.second.name}(this.cast<${caseParam.first}>());'
        },
        defaultBody: 'throw Error();',
      ),
    ),
  );
}

String _caseArgName(Type caze) =>
    caze.toString().substring(0, 1).toLowerCase() + caze.toString().substring(1);
