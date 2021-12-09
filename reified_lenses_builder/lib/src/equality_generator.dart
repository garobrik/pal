import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';

Class equalityGenerator(StringBuffer output, Class clazz) {
  final cases = clazz
      .getAnnotation(ReifiedLens)!
      .read('cases')
      .listValue
      .map((c) => Type.fromDartType(clazz.element!.library, c.toTypeValue()!));

  return Class(
    clazz.isPrivate ? '${clazz.name}Mixin' : '_${clazz.name}Mixin',
    isAbstract: true,
    params: clazz.params,
    accessors: [
      if (cases.isEmpty)
        for (final field in clazz.fields)
          if (!field.isStatic) AccessorPair(field.name, getter: Getter(field.name, field.type)),
      if (cases.isEmpty)
        AccessorPair(
          'hashCode',
          getter: Getter(
            'hashCode',
            clazz.intType,
            isExpression: false,
            annotations: const ['@override'],
            body: statements([
              'int hash = 0',
              for (final field in clazz.fields)
                if (!field.isStatic) ...[
                  'hash = 0x1fffffff & (hash + ${field.name}.hashCode)',
                  'hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10))',
                  'hash = hash ^ (hash >> 6)',
                ],
              'hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3))',
              'hash = hash ^ (hash >> 11)',
              'return 0x1fffffff & (hash + ((0x00003fff & hash) << 15))',
            ]),
          ),
        ),
    ],
    methods: [
      if (cases.isEmpty)
        Method(
          '==',
          annotations: const ['@override'],
          isExpression: true,
          returnType: clazz.boolType,
          params: [
            Param(clazz.objectType, 'other'),
          ],
          body: [
            'other is ${clazz.name}',
            for (final field in clazz.fields)
              if (!field.isStatic) '${field.name} == other.${field.name}',
          ].join(' && '),
        ),
    ],
  );
}
