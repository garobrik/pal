import 'package:reified_lenses/annotations.dart';

import 'package:parse_generate/parse_generate.dart';
import 'optics.dart';

Iterable<Optic> generateAccessorOptics(Class clazz) {
  return clazz.accessors.expand((a) {
    if (a.getter == null || !a.getter!.hasAnnotation(ReifiedLens) || a.name == 'hashCode') {
      return [];
    }
    final getter = a.getter!;
    final mutaters = clazz.methods.where((m) => m.name == 'mut_${a.name}');
    final mutater = mutaters.isEmpty ? null : mutaters.first;

    if (mutater != null) {
      assert(mutater.params.length == 1);
      Param param = mutater.params.first;
      assert(!param.isNamed);
      assert(
        mutater.returnType != null && mutater.returnType!.typeEquals(clazz.type),
      );
      assert(
        param.type.typeEquals(
          FunctionType(
            returnType: getter.returnType,
            requiredArgs: [getter.returnType],
          ),
        ),
      );
    }
    final kind = mutater == null ? OpticKind.getter : OpticKind.lens;
    return [
      Optic(
        kind: kind,
        generateAccessors: (wrapper) => [
          AccessorPair(a.name,
              getter: Getter(
                a.name,
                wrapper(getter.returnType),
                body: call(kind.thenMethod, [
                  call(
                      kind.fieldCtor,
                      [
                        "const Vec(['${a.name}'])",
                        '(t) => t.${a.name}',
                        if (kind == OpticKind.lens) '(t, f) => t.${mutater!.name}(f(t.${a.name}))',
                      ],
                      typeArgs: a.getter!.returnType.typeEquals(Type.dynamic)
                          ? [clazz.type, a.getter!.returnType]
                          : [])
                ], typeArgs: [
                  if (a.getter!.returnType.typeEquals(Type.dynamic)) a.getter!.returnType
                ]),
              ),
              setter: null
              // : Setter(
              //     a.name,
              //     mutater!.params.first,
              //     isExpression: true,
              //     body: '${a.name}.set(${mutater.params.first.name})',
              //   ),
              ),
        ],
      )
    ];
  });
}
