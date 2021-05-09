import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';
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
    final kind = mutater == null ? OpticKind.Getter : OpticKind.Lens;
    return [
      Optic(
        kind: kind,
        generateAccessors: (wrapper, parentKind) => [
          AccessorPair(
            a.name,
            getter: Getter(
              a.name,
              wrapper(getter.returnType),
              body: call(parentKind.thenMethod, [
                call(parentKind.fieldCtor, [
                  "'${a.name}'",
                  '(_t) => _t.${a.name}',
                  if (parentKind == OpticKind.Lens)
                    '(_t, _f) => _t.${mutater!.name}(_f(_t.${a.name}))',
                ])
              ]),
            ),
            setter: true //parentKind == OpticKind.Getter
                ? null
                : Setter(
                    a.name,
                    mutater!.params.first,
                    isExpression: true,
                    body: '${a.name}.set(${mutater.params.first.name})',
                  ),
          ),
        ],
      )
    ];
  });
}
