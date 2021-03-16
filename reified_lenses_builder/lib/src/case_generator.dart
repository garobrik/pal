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

  Extension(
    '${clazz.name}CasesCursorExtension',
    Type('Cursor', args: [clazz.type]),
    params: clazz.params,
    accessors: [_generateCaseGetter(clazz, cases)],
    methods: [_generateCasesMethod(clazz, cases)],
  ).declare(output);

  final casesClassName = '${clazz.name}Case';
  Class(
    casesClassName,
    annotations: ['@immutable'],
    constructors: (clazz) => [
      Constructor(
          parent: clazz,
          name: '_',
          isConst: true,
          params: [Param(Type.type, 'type', isInitializingFormal: true)])
    ],
    fields: [
      Field('type', type: Type.type, isFinal: true),
      _generateValues(clazz, cases),
      for (final caze in cases)
        Field(
          _caseArgName(caze),
          type: Type(casesClassName),
          isStatic: true,
          isConst: true,
          initializer: '$casesClassName._(${caze.toString()})',
        ),
    ],
    methods: [_generateTypeCases(clazz, cases), _generateEachCases(clazz, cases)],
  ).declare(output);
}

AccessorPair _generateCaseGetter(Class clazz, Iterable<Type> cases) {
  final param = Param(clazz.type, '_value');
  final ifElsePart = ifElse(
    {for (final caze in cases) '${param.name} is $caze': 'return ${clazz.name}Case.${_caseArgName(caze)};'},
    elseBody: 'throw Exception(\'${clazz.name} type cursor getter: unknown subtype\');',
  );

  return AccessorPair(
    'caze',
    getter: Getter(
      'caze',
      Type('GetCursor', args: [Type('${clazz.name}Case')]),
      body: '''
        thenGet<${clazz.name}Case>(Getter.field(\'case\', ($param) { $ifElsePart }))
    ''',
    ),
  );
}

Method _generateCasesMethod(Class clazz, Iterable<Type> cases) {
  final typeParam = clazz.newTypeParams(1).first;
  final params = cases.map(
    (caze) => Param(
      FunctionType(returnType: typeParam.type, requiredArgs: [
        Type('Cursor', args: [caze])
      ]),
      _caseArgName(caze),
      isNamed: true,
      isRequired: true,
    ),
  );

  return Method(
    'cases',
    typeParams: [typeParam],
    returnType: typeParam.type,
    params: params,
    isExpression: true,
    body: call(
      'caze.get.cases',
      [],
      named: {
        for (final caseParam in zip(cases, params))
          '${_caseArgName(caseParam.first)}': '() => ${caseParam.second.name}(this.cast<${caseParam.first}>())'
      },
    ),
  );
}

Method _generateTypeCases(Class clazz, Iterable<Type> cases) {
  final typeParam = clazz.newTypeParams(1).first;
  final params = cases.map(
    (caze) => Param(
      FunctionType(returnType: typeParam.type),
      _caseArgName(caze),
      isNamed: true,
      isRequired: true,
    ),
  );

  return Method(
    'cases',
    typeParams: [typeParam],
    returnType: typeParam.type,
    params: params,
    body: switchCase(
      'type',
      {
        for (final caseParam in zip(cases, params))
          '${caseParam.first}': 'return ${caseParam.second.name}();'
      },
      defaultBody: 'throw Exception(\'${clazz.name} cases cursor method: unkown subtype\');',
    ),
  );
}

Field _generateValues(Class clazz, Iterable<Type> cases) {
  return Field(
    'values',
    isStatic: true,
    isConst: true,
    type: Type('List', args: [Type('${clazz.name}Case')]),
    initializer: '[' + cases.map((caze) => '${clazz.name}Case.${_caseArgName(caze)},').join(' ') + ']',
  );
}

Method _generateEachCases(Class clazz, Iterable<Type> cases) {
  final typeParam = clazz.newTypeParams(1).first;
  final params = cases.map(
    (caze) => Param(
      FunctionType(returnType: typeParam.type),
      _caseArgName(caze),
      isNamed: true,
      isRequired: true,
    ),
  );

  return Method(
    'each',
    isStatic: true,
    typeParams: [typeParam],
    returnType: Type('List', args: [typeParam.type]),
    params: params,
    isExpression: true,
    body: '[' + params.map((p) => '${p.name}(),').join(' ') + ']',
  );
}

String _caseArgName(Type caze) =>
    caze.toString().substring(0, 1).toLowerCase() + caze.toString().substring(1);
