import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:reified_lenses/annotations.dart';
import 'dart:core' as core;
import 'dart:core';

import 'parsing.dart';
import 'generating.dart';

// TODO: how does this work with qualified type names?

class GeneratorContext {
  final Class clazz;
  final TypeParam newTypeParam;
  late final Constructor? copyCtor;
  late final Method? copyWith;

  GeneratorContext(this.clazz) : newTypeParam = clazz.newTypeParams(1).first {
    // ignore: unnecessary_cast, doesn't type check otherwise
    final existingCopyWith = (clazz.methods as Iterable<Method?>)
        .firstWhere((m) => m!.name == 'copyWith', orElse: () => null);
    if (existingCopyWith != null) {
      copyWith = existingCopyWith;
      copyCtor = null;
      return;
    }

    final annotated =
        clazz.constructors.where((c) => c.hasAnnotation(CopyConstructor));
    // ignore: unnecessary_cast, doesn't type check otherwise
    final named = (clazz.constructors as Iterable<Constructor?>)
        .firstWhere((c) => c!.name == 'copyConstructor', orElse: () => null);
    if (annotated.isNotEmpty) {
      if (annotated.length > 1) {
        throw StateError('Only one copy constructor allowed.');
      }
      copyCtor = annotated.first;
    } else if (named != null) {
      copyCtor = named;
    } else if (clazz.defaultCtor == null) {
      copyCtor = null;
    } else if (!clazz.isAbstract &&
        clazz.defaultCtor!.params.every((p) => p.isNamed)) {
      copyCtor = clazz.defaultCtor;
    } else {
      copyCtor = null;
    }

    if (copyCtor != null) {
      final params = copyCtor!.params.map((p) =>
          Param(p.type.asNullable, p.name, isRequired: false, isNamed: true));
      copyWith = Method(
        'copyWith',
        returnType: copyCtor!.parent,
        params: params,
      );
    } else {
      copyWith = null;
    }
  }

  Iterable<Optic> generateOptics() {
    return [
      ...generateFieldOptics(),
      ...generateAccessorOptics(),
      ...generateMethodOptics(),
    ];
  }

  Iterable<Optic> generateFieldOptics() {
    return clazz.fields.expand((f) {
      if (f.isStatic || f.hasAnnotation(SkipLens)) return [];
      OpticKind kind;
      if (copyCtor != null && copyCtor!.params.any((p) => p.name == f.name)) {
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
      if (a.getter == null ||
          a.getter!.hasAnnotation(SkipLens) ||
          a.name == 'hashCode') {
        return [];
      }
      // ignore: unnecessary_cast, doesn't type check otherwise
      final mutater = (clazz.methods as Iterable<Method?>)
          .firstWhere((m) => m!.name == 'mut_${a.name}', orElse: () => null);
      final kind = mutater == null ? OpticKind.Getter : OpticKind.Lens;
      return [
        Optic(
          name: a.name,
          kind: kind,
          zoomedType: a.getter!.returnType,
          mutBody: mutater == null
              ? null
              : '(t, s) => t.${mutater.name}(s(t.${a.name}))',
        )
      ];
    });
  }

  // TODO: handle multi-arg methods & method names
  Iterable<Optic> generateMethodOptics() {
    return clazz.methods.expand((m) {
      if (m.hasAnnotation(SkipLens) ||
          m.name == '==' ||
          m.name == 'toString' ||
          m.name.startsWith('mut_') ||
          m.isStatic ||
          m.returnType == null) return [];

      final mutaterName = m.name == '[]' ? 'mut_array_op' : 'mut_${m.name}';
      // ignore: unnecessary_cast, doesn't type check otherwise
      final mutater = (clazz.methods as Iterable<Method?>)
          .firstWhere((m) => m!.name == mutaterName, orElse: () => null);
      final kind = mutater == null ? OpticKind.Getter : OpticKind.Lens;
      final argName = m.params.first.name;
      return [
        Optic(
          name: m.name,
          kind: kind,
          zoomedType: m.returnType!,
          optic: call('${kind.opticName}.field', [
            argName,
            lambda(
              ['_t'],
              [
                m.invoke('_t', [argName])
              ],
            ),
            if (mutater != null)
              lambda(
                ['_t', '_s'],
                [
                  mutater.invoke('_t', [
                    argName,
                    call('_s', [
                      m.invoke('_t', [argName])
                    ])
                  ])
                ],
              ),
          ]),
          params: m.params,
          typeParams: m.typeParams,
        )
      ];
    });
  }
}

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

    return generateForContext(GeneratorContext(Class.fromElement(element)));
  }

  String generateForContext(GeneratorContext ctx) {
    final output = StringBuffer();

    generateCopyWithExtension(ctx, output);
    final optics = ctx.generateOptics();
    composers.forEach((composer) {
      OpticKind.values.forEach((kind) {
        final opticsOfKind = optics.where(
          (o) => o.kind == kind || kind == OpticKind.Getter,
        );
        if (opticsOfKind.isEmpty) return;
        output.writeln(composer.extensionDecl(ctx.clazz, kind));
        output.writeln();
        opticsOfKind.forEach((o) => o.generate(ctx, composer, kind, output));
        output.writeln('}');
      });
    });

    return output.toString();
  }

  void generateCopyWithExtension(GeneratorContext ctx, StringBuffer output) {
    if (ctx.copyCtor == null) return;
    final copyCtor = ctx.copyCtor!;

    if (copyCtor.params.any((p) => !p.isNamed)) return;

    final name = '${ctx.clazz.name}CopyWithExtension';
    final params = ctx.clazz.typeParams.asDeclaration;
    final on = ctx.clazz;
    output.writeln('extension $name$params on $on {');
    output.writeln();
    generateCopyWithMethod(copyCtor, ctx.copyWith!, output);
    output.writeln('}');
  }

  void generateCopyWithMethod(
      Constructor constructor, Method method, StringBuffer output) {
    final params = constructor.params
        .map((p) => Param(p.type, p.name, isNamed: true, isRequired: false));
    output.writeln(method.declaration(call(
      constructor.call,
      params.map((p) => '${p.name}: ${p.name} ?? this.${p.name}'),
    )));
  }
}

class Composer {
  final String Function(OpticKind) types;
  final int numParams;

  Composer({required this.types, required this.numParams});

  Type zoom(Class clazz, Type t, OpticKind k) =>
      Type(types(k), args: [...clazz.newTypeParams(numParams), t]);

  String extensionDecl(Class clazz, OpticKind kind) {
    final name = '${clazz.name}${types(kind)}Extension';
    final params = [...clazz.newTypeParams(numParams), ...clazz.typeParams];
    final on =
        Type(types(kind), args: [...clazz.newTypeParams(numParams), clazz]);

    return 'extension $name${params.asDeclaration} on ${on} {';
  }
}

final composers = [
  Composer(
    types: (k) => k.allCases(
      lens: 'Cursor',
      getter: 'GetCursor',
    ),
    numParams: 0,
  ),
  Composer(
    types: (k) => k.allCases(
      getter: 'Getter',
      lens: 'Lens',
    ),
    numParams: 1,
  )
];

class Optic {
  final OpticKind kind;
  final Type zoomedType;
  final Iterable<TypeParam> typeParams;
  final Iterable<Param> params;
  final String? optic;
  final String? mutBody;
  final String? getBody;
  final String name;

  const Optic({
    required this.kind,
    required this.name,
    required this.zoomedType,
    this.optic,
    this.mutBody,
    this.getBody,
    this.typeParams = const [],
    this.params = const [],
  });

  void generate(GeneratorContext ctx, Composer composer, OpticKind parentKind,
      StringBuffer output) {
    final thenArg = optic != null
        ? optic!
        : call(
            '${parentKind.opticName}.field',
            [
              "'${name}'",
              getBody != null ? getBody! : '(t) => t.${name}',
              if (parentKind == OpticKind.Lens)
                mutBody != null
                    ? mutBody!
                    : '(t, f) => t.copyWith(${name}: f(t.${name}))',
            ],
          );
    final returnType = composer.zoom(ctx.clazz, zoomedType, parentKind);

    if (params.isEmpty) {
      final getter = Getter(name, returnType);
      output
          .writeln(getter.declaration(call(parentKind.thenMethod, [thenArg])));
    } else {
      final method = Method(
        name,
        typeParams: typeParams,
        params: params,
        returnType: returnType,
      );

      output
          .writeln(method.declaration(call(parentKind.thenMethod, [thenArg])));
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
}
