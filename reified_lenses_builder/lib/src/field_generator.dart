import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';
import 'optics.dart';

Iterable<Optic> generateFieldOptics(
  Class clazz,
  Iterable<Param> copyWithParams,
) {
  return clazz.fields.expand((f) {
    if (f.isStatic || f.hasAnnotation(Skip)) return [];
    late final OpticKind kind;
    if (copyWithParams.any((p) => p.name == f.name)) {
      kind = OpticKind.Lens;
    } else {
      kind = OpticKind.Getter;
    }

    return [
      Optic(
        kind: kind,
        generateAccessors: (wrapper, parentKind) => [
          AccessorPair(
            f.name,
            getter: Getter(
              f.name,
              wrapper(f.type),
              body: call(parentKind.thenMethod, [
                call(parentKind.fieldCtor, [
                  "'${f.name}'",
                  '(_t) => _t.${f.name}',
                  if (parentKind == OpticKind.Lens)
                    '(_t, _f) => _t.copyWith(${f.name}: _f(_t.${f.name}))'
                ])
              ]),
            ),
            setter: true //parentKind == OpticKind.Getter
                ? null
                : Setter(
                    f.name,
                    Param(f.type, f.name),
                    isExpression: true,
                    body: 'this.${f.name}.set(${f.name})',
                  ),
          )
        ],
      ),
    ];
  });
}
