import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';
import 'optics.dart';

Class maybeGenerateCasesExtension(StringBuffer output, Class clazz) {
  final cases = clazz
      .getAnnotation(ReifiedLens)!
      .read('cases')
      .listValue
      .map((c) => Type.fromDartType(clazz.element!.library, c.toTypeValue()!));

  if (cases.isNotEmpty) {
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
      methods: [
        _generateTypeCases(clazz, cases),
        _generateEachCases(clazz, cases),
        Method(
          'toString',
          returnType: Type('String'),
          annotations: ['@override'],
          isExpression: true,
          body: 'type.toString()',
        ),
      ],
    ).declare(output);
  }

  return Class(
    clazz.isPrivate ? '${clazz.name}Mixin' : '_${clazz.name}Mixin',
    isAbstract: true,
    params: clazz.params,
    methods: [if (cases.isNotEmpty) _generateConcreteCasesMethod(clazz, cases)],
  );
}

Method _generateConcreteCasesMethod(Class clazz, Iterable<Type> cases) {
  final typeParam = clazz.newTypeParams(1).first;
  return Method('cases',
      typeParams: [typeParam],
      returnType: typeParam.type,
      params: [
        for (final caze in cases)
          Param(
            FunctionType(returnType: typeParam.type, requiredArgs: [caze]),
            _caseArgName(caze),
            isNamed: true,
            isRequired: true,
          ),
      ],
      body: ifElse(
        {
          for (final caze in cases)
            'this is $caze': 'return ${call(_caseArgName(caze), ["this as $caze"])};'
        },
        elseBody: 'throw Exception(\'${clazz.name} cases method: unknown subtype\');',
      ));
}

AccessorPair _generateCaseGetter(Class clazz, Iterable<Type> cases) {
  final param = Param(clazz.type, '_value');
  final ifElsePart = ifElse(
    {
      for (final caze in cases)
        '${param.name} is $caze': 'return ${clazz.name}Case.${_caseArgName(caze)};'
    },
    elseBody: 'throw Exception(\'${clazz.name} type cursor getter: unknown subtype\');',
  );

  return AccessorPair(
    'caze',
    getter: Getter(
      'caze',
      Type('GetCursor', args: [Type('${clazz.name}Case')]),
      body: '''
        thenGet<${clazz.name}Case>(${OpticKind.Getter.fieldCtor}([\'case\'], ($param) { $ifElsePart }))
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
    params: [Param(Type('Reader'), 'reader'), ...params],
    isExpression: true,
    body: call(
      'caze.read(reader).cases',
      [],
      named: {
        for (final caseParam in zip(cases, params))
          '${_caseArgName(caseParam.first)}': '() => ${caseParam.second.name}(this.cast())'
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
    initializer:
        '[' + cases.map((caze) => '${clazz.name}Case.${_caseArgName(caze)},').join(' ') + ']',
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
