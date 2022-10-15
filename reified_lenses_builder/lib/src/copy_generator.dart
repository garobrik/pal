import 'package:reified_lenses/annotations.dart';

import 'package:parse_generate/parse_generate.dart';

Pair<Class?, Iterable<Field>> maybeGenerateCopyWithExtension(StringBuffer output, Class clazz) {
  final cases = clazz.getAnnotation(ReifiedLens)!.read('cases').listValue;
  if (cases.isNotEmpty) return const Pair(null, []);

  final ctor = _findCopyConstructor(clazz);

  if (ctor == null) return const Pair(null, []);
  final copyWithMethod = _generateConcreteCopyWithFunction(clazz, ctor);
  if (copyWithMethod.second.isEmpty) return const Pair(null, []);
  final ext = Class(
    clazz.isPrivate ? '${clazz.name}Mixin' : '_${clazz.name}Mixin',
    isAbstract: true,
    params: clazz.params,
    accessors: [AccessorPair(copyWithMethod.first.name, getter: copyWithMethod.first)],
  );

  return Pair(ext, copyWithMethod.second);
}

// the nifty undefined trick used here for capturing the difference between explicitly passing null
// vs omitting an argument is copied from https://github.com/rrousselGit/freezed, thanks remi!
Pair<Getter, Iterable<Field>> _generateConcreteCopyWithFunction(
  Class clazz,
  Constructor constructor,
) {
  final paramsNoSkip = constructor.params.where((p) {
    final field = clazz.fields.firstWhere((f) => f.name == p.name);
    return !field.hasAnnotation(Skip) && !field.hasAnnotation(GetterAnnotation);
  }).map((p) => Param(p.type.withNullable(true), p.name, isNamed: true, isRequired: false));
  final paramsAsObject = paramsNoSkip.map(
    (p) => Param(
      Type.object.withNullable(true),
      p.name,
      isNamed: true,
      isRequired: false,
      defaultValue: 'undefined',
    ),
  );
  Type functionType =
      FunctionType.fromParams(returnType: constructor.parent.type, params: paramsNoSkip);
  final constructorArgs = constructor.params.map(
    (p) {
      final skipField = clazz.fields.firstWhere((f) => f.name == p.name).hasAnnotation(Skip);
      final body =
          skipField ? p.name : '${p.name} == undefined ? this.${p.name} : ${p.name} as ${p.type}';
      return p.isNamed ? '${p.name}: $body,' : '$body,';
    },
  );

  final getter = Getter(
    'copyWith',
    functionType,
    body: '(${paramsAsObject.asDeclaration}) => ${constructor.call}(${constructorArgs.join()})',
  );

  return Pair(
    getter,
    paramsNoSkip.map((p) => clazz.fields.firstWhere((f) => f.name == p.name)),
  );
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
        (p) => clazz.fields.any((f) =>
            f.name == p.name && f.type.withNullable(false).typeEquals(p.type.withNullable(false))),
      ) &&
      clazz.fields.where((f) => !f.hasAnnotation(Skip)).every(
            (f) => constructor.params.any(
              (p) =>
                  p.name == f.name &&
                  f.type.withNullable(false).typeEquals(p.type.withNullable(false)),
            ),
          );
}
