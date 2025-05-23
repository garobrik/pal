import 'dart:async';
import 'dart:core' as core;
import 'dart:core';

import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:parse_generate/parse_generate.dart';
import 'package:reified_lenses/annotations.dart';
import 'package:source_gen/source_gen.dart';

import 'accessor_generator.dart';
import 'case_generator.dart';
import 'copy_generator.dart';
import 'equality_generator.dart';
import 'field_generator.dart';
import 'method_generator.dart';
import 'mutation_generator.dart';
import 'optics.dart';
import 'serialization_generator.dart';

class ReifiedLensesGenerator extends Generator {
  const ReifiedLensesGenerator();

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    final output = StringBuffer();

    final reifiedClassesWithCases = [
      for (final classElem in library.classes)
        if (classElem.hasAnnotation(ReifiedLens)) Class.fromElement(library.element, classElem),
    ];

    final reifiedClasses = reifiedClassesWithCases.where((clazz) {
      final parentAnnotation =
          (clazz.extendedType?.dartType as InterfaceType?)?.element2.getAnnotation(ReifiedKind);
      if (parentAnnotation == null) return true;
      return ReifiedKind.union.index !=
          parentAnnotation.read('type').objectValue.getField('index')!.toIntValue();
    });

    for (final clazz in reifiedClasses) {
      final copyWithExtAndParams = maybeGenerateCopyWithExtension(output, clazz);
      final copyWithParams = copyWithExtAndParams.second;
      final optics = [
        ...generateFieldOptics(clazz, copyWithParams),
        ...generateAccessorOptics(clazz),
        ...generateMethodOptics(clazz),
      ];
      for (final composer in composers) {
        for (final kind in OpticKind.values) {
          composer.extension(clazz, kind, optics)?.declare(output);
        }
      }
      generateMutations(output, clazz);

      final mixins = <Class>[
        if (copyWithExtAndParams.first != null) copyWithExtAndParams.first!,
        maybeGenerateSerialization(output, clazz, copyWithParams),
        equalityGenerator(output, clazz),
        maybeGenerateCasesExtension(output, clazz),
      ];

      Class(
        mixins.first.name,
        params: mixins.first.params,
        isAbstract: mixins.first.isAbstract,
        accessors: mixins.expand((m) => m.accessors),
        fields: mixins.expand((m) => m.fields),
        methods: mixins.expand((m) => m.methods),
      ).declare(output);
    }

    return output.toString();
  }
}

class OpticComposer {
  final String Function(OpticKind) typeOf;
  final int numParams;

  OpticComposer({required this.typeOf, required this.numParams});

  Type zoom(Class clazz, Type type, OpticKind kind) =>
      Type(typeOf(kind), args: [...clazz.newTypeParams(numParams).map((tp) => tp.type), type]);

  Extension? extension(Class clazz, OpticKind kind, Iterable<Optic> optics) {
    final opticsOfKind = optics.where(
      (o) => o.kind == kind || kind == OpticKind.getter,
    );
    if (opticsOfKind.isEmpty) return null;

    final name = '${clazz.name}${typeOf(kind)}Extension';
    final newParams = clazz.newTypeParams(numParams);
    final params = [...newParams, ...clazz.params];
    Type wrapper(Type type) => Type(typeOf(kind), args: [...newParams.map((tp) => tp.type), type]);

    return Extension(
      name,
      wrapper(clazz.type),
      params: params,
      methods: opticsOfKind.expand((optic) => optic.generateMethods(wrapper, kind)),
      accessors: opticsOfKind.expand((optic) => optic.generateAccessors(wrapper)),
    );
  }
}

final composers = [
  OpticComposer(
    typeOf: (kind) => kind.cases(
      lens: 'Cursor',
      getter: 'GetCursor',
    ),
    numParams: 0,
  ),
  // OpticComposer(
  //   typeOf: (kind) => kind.cases(
  //     getter: 'Getter',
  //     lens: 'Lens',
  //   ),
  //   numParams: 1,
  // )
];
