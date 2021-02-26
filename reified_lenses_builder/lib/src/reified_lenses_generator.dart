import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:reified_lenses/annotations.dart';
import 'dart:core' as core;
import 'dart:core';

import 'copy_generator.dart';
import 'case_generator.dart';
import 'mutation_generator.dart';
import 'parsing.dart';
import 'generating.dart';

// TODO: how does this work with qualified type names?
class ReifiedLensesGenerator extends GeneratorForAnnotation<ReifiedLens> {
  const ReifiedLensesGenerator();

  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@reified_lens can only be applied on classes, was applied to ${element.name}.',
        element: element,
      );
    }

    final output = StringBuffer();
    GeneratorContext(Class.fromElement(element)).generate(output);
    return output.toString();
  }
}

class GeneratorContext {
  final Class clazz;

  GeneratorContext(this.clazz);

  void generate(StringBuffer output) {
    final copyWithParams = maybeGenerateCopyWithExtension(output, clazz);
    final optics = [
      ...generateFieldOptics(copyWithParams),
      ...generateAccessorOptics(),
      ...generateMethodOptics(),
    ];
    generateMutations(output, clazz);
    maybeGenerateCasesExtension(output, clazz);
    composers.forEach((composer) {
      OpticKind.values.forEach((kind) {
        final opticsOfKind = optics.where(
          (o) => o.kind == kind || kind == OpticKind.Getter,
        );
        if (opticsOfKind.isEmpty) return;

        composer.extension(clazz, kind).declare(
              output,
              (output) => opticsOfKind.forEach(
                (o) => o.generate(this, composer, kind, output),
              ),
            );
      });
    });
  }

  Iterable<Optic> generateFieldOptics(Iterable<Param>? copyWithParams) {
    return clazz.fields.expand((f) {
      if (f.isStatic || f.hasAnnotation(Skip)) return [];
      late final OpticKind kind;
      if (copyWithParams != null && copyWithParams.any((p) => p.name == f.name)) {
        kind = OpticKind.Lens;
      } else {
        kind = OpticKind.Getter;
      }

      return [
        Optic(
          name: f.name,
          zoomedType: f.type,
          kind: kind,
        )
      ];
    });
  }

  Iterable<Optic> generateAccessorOptics() {
    return clazz.accessors.expand((a) {
      if (a.getter == null || !a.getter!.hasAnnotation(ReifiedLens) || a.name == 'hashCode') {
        return [];
      }
      final getter = a.getter!;
      // ignore: unnecessary_cast, doesn't type check otherwise
      final mutater = (clazz.methods as Iterable<Method?>)
          .firstWhere((m) => m!.name == 'mut_${a.name}', orElse: () => null);
      if (mutater != null) {
        assert(mutater.params.length == 1);
        Param param = mutater.params.first;
        assert(!param.isNamed);
        assert(
          mutater.returnType != null && mutater.returnType!.typeEquals(clazz),
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
          name: getter.name,
          kind: kind,
          zoomedType: getter.returnType,
          mutBody: mutater == null ? null : '(t, s) => t.${mutater.name}(s(t.${a.name}))',
        )
      ];
    });
  }

  // TODO: handle multi-arg methods & method names
  Iterable<Optic> generateMethodOptics() {
    return clazz.methods.expand((m) {
      if (!m.hasAnnotation(ReifiedLens) ||
          m.name == '==' ||
          m.name == 'toString' ||
          m.name.startsWith('mut_') ||
          m.isStatic ||
          m.returnType == null) return [];

      final mutaterName = m.name == '[]' ? 'mut_array_op' : 'mut_${m.name}';
      // ignore: unnecessary_cast, doesn't type check otherwise
      final mutater = (clazz.methods as Iterable<Method?>)
          .firstWhere((m) => m!.name == mutaterName, orElse: () => null);

      late final Param? updateParam;
      if (mutater != null) {
        final updateParamCandidates = mutater.params.where((p) => p.name == 'update');
        assert(updateParamCandidates.isNotEmpty);
        assert(
          mutater.params.where((p) => p != updateParam).iterableEqual(m.params),
        );
        updateParam = updateParamCandidates.first;
      } else {
        updateParam = null;
      }

      final kind = mutater == null ? OpticKind.Getter : OpticKind.Lens;

      return [
        Optic(
          name: m.name,
          kind: kind,
          zoomedType: m.returnType!,
          fieldArg:
              "Vec<dynamic>(<dynamic>['${m.name}', ${m.params.asArgs()}])", // TODO: doesn't work for named params
          getBody: '(_t) => ${m.invokeFromParams("_t", typeArgs: m.typeParams)}',
          mutBody: mutater == null
              ? null
              : '(_t, _s) => ${mutater.invokeFromParams("_t", genArg: (p) => p == updateParam ? "_s" : p.name, typeArgs: m.typeParams)}',
          params: m.params,
          typeParams: m.typeParams,
        )
      ];
    });
  }
}

class OpticComposer {
  final String Function(OpticKind) typeOf;
  final int numParams;

  OpticComposer({required this.typeOf, required this.numParams});

  Type zoom(Class clazz, Type type, OpticKind kind) =>
      Type(typeOf(kind), args: [...clazz.newTypeParams(numParams), type]);

  Extension extension(Class clazz, OpticKind kind) {
    final name = '${clazz.name}${typeOf(kind)}Extension';
    final params = [...clazz.newTypeParams(numParams), ...clazz.params];
    final on = Type(
      typeOf(kind),
      args: [...clazz.newTypeParams(numParams), clazz],
    );

    return Extension(name, on, params: params);
  }
}

final composers = [
  OpticComposer(
    typeOf: (kind) => kind.allCases(
      lens: 'Cursor',
      getter: 'GetCursor',
    ),
    numParams: 0,
  ),
  OpticComposer(
    typeOf: (kind) => kind.allCases(
      getter: 'Getter',
      lens: 'Lens',
    ),
    numParams: 1,
  )
];

class Optic {
  final OpticKind kind;
  final String name;
  final Type zoomedType;
  final Iterable<TypeParam> typeParams;
  final Iterable<Param> params;
  final String? opticImpl;
  final String? mutBody;
  final String? getBody;
  final String? fieldArg;

  const Optic({
    required this.kind,
    required this.name,
    required this.zoomedType,
    this.opticImpl,
    this.mutBody,
    this.getBody,
    this.fieldArg,
    this.typeParams = const [],
    this.params = const [],
  });

  void generate(
      GeneratorContext ctx, OpticComposer composer, OpticKind parentKind, StringBuffer output) {
    late final thenArg = opticImpl ??
        call(
          parentKind.fieldCtor,
          [
            fieldArg ?? "'${name}'",
            getBody ?? '(t) => t.${name}',
            if (parentKind == OpticKind.Lens)
              mutBody ?? '(t, f) => t.copyWith(${name}: f(t.${name}))',
          ],
        );
    final returnType = composer.zoom(ctx.clazz, zoomedType, parentKind);

    if (params.isEmpty) {
      final getter = Getter(name, returnType);
      output.writeln(
        getter.declare(body: call(parentKind.thenMethod, [thenArg])),
      );
    } else {
      final method = Method(
        name,
        typeParams: typeParams,
        params: params,
        returnType: returnType,
      );

      method.declare(output, body: call(parentKind.thenMethod, [thenArg]));
    }
    output.writeln();
  }
}

extension on OpticKind {
  A allCases<A>({
    required A lens,
    required A getter,
  }) {
    switch (this) {
      case OpticKind.Lens:
        return lens;
      case OpticKind.Getter:
        return getter;
    }
  }

  String get thenMethod => this.allCases(lens: 'then', getter: 'thenGet');

  String get opticName => this.allCases(lens: 'Lens', getter: 'Getter');

  String get fieldCtor => '$opticName.field';
}
