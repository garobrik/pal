import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'optional.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';
import 'package:reified_lenses/annotations.dart';
import 'dart:core' as Core;
import 'dart:core';

import 'parsing.dart';
import 'generating.dart';

class GeneratorContext {
  final Class clazz;
  final TypeParam newTypeParam;
  Optional<Constructor> copyCtor;
  Optional<Method> copyWith;

  GeneratorContext(this.clazz) : newTypeParam = clazz.newTypeParams(1).first {
    copyWith = Optional.nullable(clazz.methods
        .firstWhere((m) => m.name == 'copyWith', orElse: () => null));
    if (copyWith.isNotEmpty) {
      copyCtor = Optional.empty();
      return;
    }

    final annotated =
        clazz.constructors.where((c) => c.hasAnnotation(CopyConstructor));
    final named = Optional.nullable(clazz.constructors
        .firstWhere((c) => c.name == 'copyConstructor', orElse: () => null));
    if (annotated.isNotEmpty) {
      if (annotated.length > 1)
        throw StateError('Only one copy constructor allowed.');
      copyCtor = Optional(annotated.first);
    } else if (named.isNotEmpty) {
      copyCtor = named;
    } else {
      copyCtor = clazz.defaultCtor.flatMap((c) => Optional.ifTrue(
          c.params.isNotEmpty &&
              !clazz.isAbstract &&
              c.params.every((p) => p.isNamed),
          c));
    }

    if (copyCtor.isNotEmpty) {
      final params = copyCtor.value.params
          .map((p) => Param(p.type, p.name, isRequired: false, isNamed: true));
      copyWith = Optional(Method(
        'copyWith',
        returnType: Optional(copyCtor.value.parent),
        params: params,
      ));
    } else {
      copyWith = Optional.empty();
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
      if (f.isPrivate || f.isStatic || f.hasAnnotation(SkipLens))
        return Optional.empty();
      OpticKind kind;
      if (copyCtor
          .map((c) => c.params.any((p) => p.name == f.name))
          .or(false)) {
        kind = OpticKind.Lens;
      } else {
        kind = OpticKind.Getter;
      }

      return Optional(Optic(
        name: f.name,
        zoomedType: f.type,
        kind: kind,
      ));
    });
  }

  Iterable<Optic> generateAccessorOptics() {
    return clazz.accessors.expand((a) {
      if (a.isPrivate ||
          a.getter.isEmpty ||
          a.getter.value.hasAnnotation(SkipLens) ||
          a.name == 'hashCode') {
        return Optional.empty();
      }
      final mutater = Optional.nullable(clazz.methods
          .firstWhere((m) => m.name == 'mut_${a.name}', orElse: () => null));
      final kind = mutater.isEmpty ? OpticKind.Getter : OpticKind.Lens;
      return Optional(Optic(
        name: a.name,
        kind: kind,
        zoomedType: a.getter.value.returnType,
        mutBody: mutater.map((m) => '(t, s) => t.${m.name}(s(t.${a.name}))'),
      ));
    });
  }

  Iterable<Optic> generateMethodOptics() {
    return clazz.methods.expand((m) {
      if (m.hasAnnotation(SkipLens) ||
          m.name == '==' ||
          m.name == 'toString' ||
          m.name.startsWith('mut_')) return Optional.empty();

      final mutaterName = m.name == '[]' ? 'mut_array_op' : 'mut_${m.name}';
      final mutater = Optional.nullable(clazz.methods
          .firstWhere((m) => m.name == mutaterName, orElse: () => null));
      final kind = mutater.isEmpty ? OpticKind.Getter : OpticKind.Lens;
      final argName = m.params.first.name;
      return Optional(Optic(
        name: m.name,
        kind: kind,
        zoomedType: m.returnType.value,
        optic: Optional(call('${kind.opticName}.field', [
          argName,
          lambda(
            ['_t'],
            [
              m.invoke('_t', [argName])
            ],
          ),
          if (mutater.isNotEmpty)
            lambda(
              ['_t', '_s'],
              [
                mutater.value.invoke('_t', [
                  argName,
                  call('_s', [
                    m.invoke('_t', [argName])
                  ])
                ])
              ],
            ),
        ])),
        params: m.params,
        typeParams: m.typeParams,
      ));
    });
  }
}

class ReifiedLensesGenerator extends GeneratorForAnnotation<ReifiedLens> {
  const ReifiedLensesGenerator();

  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement)
      throw InvalidGenerationSourceError(
        '@reified_lens can only be applied on classes, was applied to ${element.name}.',
        element: element,
      );

    return generateForContext(
        GeneratorContext(Class.fromElement(element as ClassElement)));
  }

  String generateForContext(GeneratorContext ctx) {
    final output = StringBuffer();

    generateCopyWithExtension(ctx, output);
    final optics = ctx.generateOptics();
    composers.forEach((composer) {
      OpticKind.values.forEach((kind) {
        final opticsOfKind = optics.where((o) => o.kind == kind);
        if (opticsOfKind.isEmpty) return;
        output.writeln(composer.extensionDecl(ctx.clazz, kind));
        output.writeln();
        opticsOfKind.forEach((o) => o.generate(ctx, composer, output));
        output.writeln('}');
      });
    });

    return output.toString();
  }

  void generateCopyWithExtension(GeneratorContext ctx, StringBuffer output) {
    if (ctx.copyCtor.isEmpty) return;
    final copyCtor = ctx.copyCtor.value;

    if (copyCtor.params.any((p) => !p.isNamed)) return;

    final name = '${ctx.clazz.name}CopyWithExtension';
    final params = ctx.clazz.typeParams.asDeclaration;
    final on = ctx.clazz;
    output.writeln('extension $name$params on $on {');
    output.writeln();
    generateCopyWithMethod(copyCtor, ctx.copyWith.value, output);
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

  Composer({this.types, this.numParams});

  Type zoom(Class clazz, Type t, OpticKind k) =>
      Type(types(k), [...clazz.newTypeParams(numParams), t]);

  String extensionDecl(Class clazz, OpticKind kind) {
    final name = '${clazz.name}${types(kind)}Extension';
    final params = [...clazz.newTypeParams(numParams), ...clazz.typeParams];
    final on =
        Type(types(kind), [...clazz.newTypeParams(numParams), clazz]);

    return 'extension $name${params.asDeclaration} on ${on} {';
  }
}

final composers = [
  Composer(
    types: (k) => k.allCases(
      lens: 'Cursor',
      getter: 'GetCursor',
      mutater: 'MutCursor',
    ),
    numParams: 0,
  ),
  Composer(
    types: (k) => k.allCases(
      getter: 'Getter',
      mutater: 'Mutater',
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
  final Optional<String> optic;
  final Optional<String> mutBody;
  final Optional<String> getBody;
  final String name;

  const Optic({
    @required this.kind,
    @required this.name,
    @required this.zoomedType,
    this.optic = const Optional.empty(),
    this.mutBody = const Optional.empty(),
    this.getBody = const Optional.empty(),
    this.typeParams = const [],
    this.params = const [],
  });

  void generate(GeneratorContext ctx, Composer composer, StringBuffer output) {
    final String generatedOpticName = '_\$${name}';
    String generatedOptic = generatedOpticName;
    if (optic.isEmpty) {
      final parameterizedType = kind.opticType(ctx.clazz, zoomedType);
      final substTypeParams = (Type t) => t.subst(
            ctx.clazz.typeParams,
            List.filled(ctx.clazz.typeParams.length, Type.dynamic),
          );
      final staticType = substTypeParams(parameterizedType);
      if (!parameterizedType.equals(staticType))
        generatedOptic = '$generatedOpticName as $parameterizedType';
      final staticField = Field(generatedOpticName,
          type: staticType, isStatic: true, isFinal: true);
      output.writeln(staticField.declaration(call(
        '${kind.opticName}.field',
        [
          "'${name}'",
          if ([OpticKind.Lens, OpticKind.Getter].contains(kind))
            getBody.or('(t) => t.${name}'),
          if ([OpticKind.Lens, OpticKind.Mutater].contains(kind))
            mutBody.or('(t, f) => t.copyWith(${name}: f(t.${name}))'),
        ],
        typeParams: [ctx.clazz, zoomedType].map(substTypeParams),
      )));
      output.writeln();
    }

    final thenArg = optic.or(generatedOptic);
    final opticReturnType = composer.zoom(ctx.clazz, zoomedType, kind);

    if (params.isEmpty) {
      final getter = Getter(name, opticReturnType);
      output.writeln(getter.declaration(call(kind.thenMethod, [thenArg])));
    } else {
      final method = Method(
        name,
        typeParams: typeParams,
        params: params,
        returnType: Optional(opticReturnType),
      );

      output.writeln(method.declaration(call(kind.thenMethod, [thenArg])));
    }
    output.writeln();
  }
}

extension on Class {
  bool get allFields =>
      this.getAnnotation(ReifiedLens).value.read('allFields').boolValue;
}

extension on ElementAnalogue {
  Optional<OpticKind> get opticKind {
    return this
        .getAnnotation(Optic)
        .map((kind) => OpticKind.values[kind.read('kind').intValue]);
  }
}

extension on OpticKind {
  A allCases<A>({
    @required A lens,
    @required A getter,
    @required A mutater,
  }) {
    switch (this) {
      case OpticKind.Lens:
        return lens;
      case OpticKind.Getter:
        return getter;
      case OpticKind.Mutater:
        return mutater;
    }
    throw "unreachable";
  }

  String get thenMethod =>
      this.allCases(lens: 'then', getter: 'thenGet', mutater: 'thenMut');

  String get opticName =>
      this.allCases(lens: 'Lens', getter: 'Getter', mutater: 'Mutater');

  Type opticType(Type source, Type target) => Type(opticName, [source, target]);
}
