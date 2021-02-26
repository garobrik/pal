import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';

Iterable<Param>? maybeGenerateCopyWithExtension(StringBuffer output, Class clazz) {
  final cases = clazz.getAnnotation(ReifiedLens)!.read('cases').listValue;
  final extension = Extension('${clazz.name}CopyWithExtension', clazz, params: clazz.params);

  late final Iterable<Param> params;
  if (cases.isEmpty) {
    final ctor = _findCopyConstructor(clazz);
    if (ctor == null) return null;
    extension.declare(
      output,
      (output) => params = _generateConcreteCopyWithFunction(output, ctor),
    );
  } else {
    extension.declare(
      output,
      (output) => params = _generateCaseParentCopyWithFunction(output, clazz),
    );
  }

  return params;
}

// the undefined trick used here is copied from https://github.com/rrousselGit/freezed
Iterable<Param> _generateConcreteCopyWithFunction(
  StringBuffer output,
  Constructor constructor,
) {
  final params = constructor.params
      .map((p) => Param(p.type.asNullable, p.name, isNamed: true, isRequired: false));
  final paramsAsObject = constructor.params.map(
    (p) => Param(
      Type.object.asNullable,
      p.name,
      isNamed: true,
      isRequired: false,
      defaultValue: 'undefined',
    ),
  );
  Type functionType = FunctionType.fromParams(returnType: constructor.parent, params: params);
  final getter = Getter('copyWith', functionType);
  final constructorArgs = constructor.params.map(
    (p) {
      final body = '${p.name} == undefined ? this.${p.name} : ${p.name} as ${p.type}';
      return p.isNamed ? '${p.name}: $body,' : '$body,';
    },
  );
  output.writeln(
    getter.declare(
      body: '(${paramsAsObject.asDeclaration}) => ${constructor.call}(${constructorArgs.join()})',
    ),
  );
  return params;
}

Iterable<Param> _generateCaseParentCopyWithFunction(StringBuffer output, Class clazz) {
  final cases = clazz
      .getAnnotation(ReifiedLens)!
      .read('cases')
      .listValue
      .map((caze) => Type.fromDartType(caze.toTypeValue()!));

  final params = clazz.fields.where((f) => !f.isInitialized).map(
        (f) => Param(
          f.type.asNullable,
          f.name,
          isNamed: true,
          isRequired: false,
        ),
      );

  final functionType = FunctionType.fromParams(
    returnType: clazz,
    params: params,
  );

  final getter = Getter('copyWith', functionType);

  final conditionsBodies = {
    for (final caze in cases)
      'this is $caze': 'return ((this as $caze).copyWith as ${functionType});',
  };

  output.writeln(
    getter.declare(
      expression: false,
      body: ifElse(conditionsBodies, elseBody: 'throw Error();'),
    ),
  );
  return params;
}

Constructor? _findCopyConstructor(Class clazz) {
  final annotated = clazz.constructors.where((c) => c.hasAnnotation(CopyConstructor));

  final implicits = clazz.constructors.where((ctor) => _canCopyConstruct(clazz, ctor));

  if (annotated.isNotEmpty) {
    assert(
      annotated.length == 1,
      'Multiple copy constructors found in class ${clazz.name}.',
    );
    assert(_canCopyConstruct(clazz, annotated.first));
    return annotated.first;
  } else if (!clazz.isAbstract && implicits.isNotEmpty) {
    return implicits.firstWhere(
      (c) => c.isDefault,
      orElse: () => implicits.first,
    );
  } else {
    return null;
  }
}

bool _canCopyConstruct(Class clazz, Constructor constructor) {
  return constructor.params.every(
        (p) => clazz.fields.any(
          (f) => f.name == p.name && f.type.typeEquals(p.type) && !f.hasAnnotation(Skip),
        ),
      ) &&
      clazz.fields.where((f) => !f.hasAnnotation(Skip)).every(
            (f) => constructor.params.any(
              (p) => p.name == f.name && f.type.typeEquals(p.type),
            ),
          );
}
