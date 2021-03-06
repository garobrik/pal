import 'dart:async';

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

class ReifiedLensesGenerator extends Generator {
  const ReifiedLensesGenerator();

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    final output = StringBuffer();

    for (final clazz in library.classes) {
      if (clazz.hasAnnotation(ReifiedLens)) {
        GeneratorContext(Class.fromElement(library.element, clazz)).generate(output);
      }
    }

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

  Iterable<Optic> generateFieldOptics(Iterable<Param> copyWithParams) {
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
        updateParam = updateParamCandidates.first;
        assert(
          mutater.params.where((p) => p != updateParam).iterableEqual(m.params),
        );
      } else {
        updateParam = null;
      }

      final kind = mutater == null ? OpticKind.Getter : OpticKind.Lens;
      final isFunctionalUpdate = updateParam != null && updateParam.type is FunctionType;
      final stateArg = '_t';
      final updateArg = '_s';
      final getBody = m.invokeFromParams(stateArg, typeArgs: m.typeParams);
      // TODO: this isFunctionalUpdate case can fail when a generic type has its argument cast upwards
      final mutBody = mutater?.invokeFromParams(
        stateArg,
        genArg: (p) => p != updateParam
            ? p.name
            : isFunctionalUpdate
                ? updateArg
                : '$updateArg($getBody)',
        typeArgs: m.typeParams,
      );
      return [
        Optic(
          name: m.name,
          kind: kind,
          zoomedType: m.returnType!,
          fieldArg:
              "Vec<dynamic>(<dynamic>['${m.name}', ${m.params.asArgs()}])", // TODO: doesn't work for named params
          getBody: '($stateArg) => $getBody',
          mutBody: mutBody == null ? null : '($stateArg, $updateArg) => $mutBody',
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
    final newParams = clazz.newTypeParams(numParams);
    final params = [...newParams, ...clazz.params];
    final on = Type(typeOf(kind), args: [...newParams, clazz]);

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
  final String? mutBody;
  final String? getBody;
  final String? fieldArg;

  const Optic({
    required this.kind,
    required this.name,
    required this.zoomedType,
    this.mutBody,
    this.getBody,
    this.fieldArg,
    this.typeParams = const [],
    this.params = const [],
  });

  void generate(
    GeneratorContext ctx,
    OpticComposer composer,
    OpticKind parentKind,
    StringBuffer output,
  ) {
    late final thenArg = call(
      parentKind.fieldCtor,
      [
        fieldArg ?? "'${name}'",
        getBody ?? '(t) => t.${name}',
        if (parentKind == OpticKind.Lens) mutBody ?? '(t, f) => t.copyWith(${name}: f(t.${name}))',
      ],
    );
    final returnType = composer.zoom(ctx.clazz, zoomedType, parentKind);

    if (params.isEmpty) {
      Getter(name, returnType, body: call(parentKind.thenMethod, [thenArg])).declare(output);
    } else {
      Method(
        name,
        typeParams: typeParams,
        params: params,
        returnType: returnType,
        body: call(parentKind.thenMethod, [thenArg]),
        isExpression: true,
      ).declare(output);
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
