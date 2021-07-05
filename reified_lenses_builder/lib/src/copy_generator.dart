import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';

Iterable<Param> maybeGenerateCopyWithExtension(StringBuffer output, Class clazz) {
  final cases = clazz.getAnnotation(ReifiedLens)!.read('cases').listValue;
  if (cases.isNotEmpty) return const [];

  late final Pair<Getter, Iterable<Param>> copyWithMethod;
  final ctor = _findCopyConstructor(clazz);

  if (ctor == null) return [];
  copyWithMethod = _generateConcreteCopyWithFunction(ctor);

  Extension(
    '${clazz.name}CopyWithExtension',
    clazz.type,
    params: clazz.params,
    accessors: [AccessorPair(copyWithMethod.first.name, getter: copyWithMethod.first)],
  ).declare(output);

  return copyWithMethod.second;
}

// the nifty undefined trick used here for capturing the difference between explicitly passing null
// vs omitting an argument is copied from https://github.com/rrousselGit/freezed, thanks remi!
Pair<Getter, Iterable<Param>> _generateConcreteCopyWithFunction(Constructor constructor) {
  final params = constructor.params
      .map((p) => Param(p.type.withNullable(true), p.name, isNamed: true, isRequired: false));
  final paramsAsObject = constructor.params.map(
    (p) => Param(
      Type.object.withNullable(true),
      p.name,
      isNamed: true,
      isRequired: false,
      defaultValue: 'undefined',
    ),
  );
  Type functionType = FunctionType.fromParams(returnType: constructor.parent.type, params: params);
  final constructorArgs = constructor.params.map(
    (p) {
      final body = '${p.name} == undefined ? this.${p.name} : ${p.name} as ${p.type}';
      return p.isNamed ? '${p.name}: $body,' : '$body,';
    },
  );

  final getter = Getter(
    'copyWith',
    functionType,
    body: '(${paramsAsObject.asDeclaration}) => ${constructor.call}(${constructorArgs.join()})',
  );

  return Pair(getter, params);
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
          (f) =>
              f.name == p.name &&
              f.type.withNullable(false).typeEquals(p.type.withNullable(false)) &&
              !f.hasAnnotation(Skip),
        ),
      ) &&
      clazz.fields.where((f) => !f.hasAnnotation(Skip)).every(
            (f) => constructor.params.any(
              (p) =>
                  p.name == f.name &&
                  f.type.withNullable(false).typeEquals(p.type.withNullable(false)),
            ),
          );
}
