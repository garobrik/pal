import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';
import 'optics.dart';

Iterable<Optic> generateFieldOptics(
  Class clazz,
  Iterable<Field> copyWithParams,
) {
  return clazz.fields.expand((f) {
    if (f.isStatic || f.hasAnnotation(Skip)) return [];
    late final OpticKind kind;
    if (copyWithParams.any((p) => p.name == f.name)) {
      kind = OpticKind.lens;
    } else {
      kind = OpticKind.getter;
    }

    return [
      Optic(
        kind: kind,
        generateAccessors: (wrapper) => [
          AccessorPair(
            f.name,
            getter: Getter(
              f.name,
              wrapper(f.type),
              body: call(
                kind.thenMethod,
                [
                  call(
                      kind.fieldCtor,
                      [
                        "const ['${f.name}']",
                        '(_t) => _t.${f.name}',
                        if (kind == OpticKind.lens)
                          '(_t, _f) => _t.copyWith(${f.name}: _f(_t.${f.name}))'
                      ],
                      typeArgs: f.type.typeEquals(Type.dynamic) ? [clazz.type, f.type] : [])
                ],
                typeArgs: [if (f.type.typeEquals(Type.dynamic)) f.type],
              ),
            ),
            setter: null
            // : Setter(
            //     f.name,
            //     Param(f.type, f.name),
            //     isExpression: true,
            //     body: 'this.${f.name}.set(${f.name})',
            //   )
            ,
          )
        ],
      ),
    ];
  });
}
