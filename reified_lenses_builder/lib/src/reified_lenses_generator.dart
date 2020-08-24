import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'optional.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';
import 'package:reified_lenses/reified_lenses.dart' as ReifiedLenses;
import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';

class GeneratorContext {
  final Class clazz;
  final bool allFields;
  final TypeParam newTypeParam;

  GeneratorContext(this.clazz)
      : allFields = clazz.allFields,
        newTypeParam = clazz.newTypeParam('ReifiedLens');
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
    OpticKind.values
        .forEach((kind) => generateOpticExtension(ctx, kind, output));

    return output.toString();
  }

  void generateCopyWithExtension(GeneratorContext ctx, StringBuffer output) {
    final name = '${ctx.clazz.name}CopyWithExtension';
    final params = ctx.clazz.typeParams.asDeclaration;
    final on = ctx.clazz;

    final defaultCtor = ctx.clazz.constructors.where((c) => c.name.isEmpty);
    final annotatedCtors =
        ctx.clazz.constructors.where((c) => c.hasAnnotation(CopyWith));

    final copyCtors = (annotatedCtors.isEmpty ? defaultCtor : annotatedCtors);

    output.writeln('extension $name$params on $on {');
    copyCtors.forEach((ctor) => generateCopyWithMethod(ctor, output));
    output.writeln('}');
  }

  void generateCopyWithMethod(Constructor constructor, StringBuffer output) {
    final params = constructor.params.map((p) => Param(p.type, p.name, isNamed: true, isRequired: false));
    final method = Method(
      'copyWith',
      returnType: Optional(constructor.parent),
      params: params,
    );
    output.writeln(method.declaration(call(
      constructor.call,
      params.map((p) => '${p.name}: ${p.name} ?? this.${p.name}'),
    )));
  }

  void generateOpticExtension(
      GeneratorContext ctx, OpticKind kind, StringBuffer output) {
    final fields = ctx.clazz.fields.where((field) {
      if (ctx.clazz.allFields)
        return field.opticKind.or(OpticKind.Lens) == kind;
      else
        return field.opticKind == Optional(kind);
    });
    final getters = ctx.clazz.accessors.expand((accessor) {
      if (kind != OpticKind.Getter || accessor.getter.isEmpty)
        return Optional<Getter>.empty();
      final getter = accessor.getter.value;
      final doInclude = ctx.clazz.allFields || getter.opticKind.hasValue;
      return Optional.ifTrue(doInclude, getter);
    });
    final methods =
        ctx.clazz.methods.where((method) => method.opticKind == Optional(kind));

    final generateFor = <ElementAnalogue>[...fields, ...getters, ...methods];

    output.writeln(extensionDecl(ctx, kind));
    if (kind == OpticKind.Lens) {

    }
    generateFor.forEach((elem) => generateForElement(ctx, elem, kind, output));
    output.writeln('}');
  }

  String extensionDecl(GeneratorContext ctx, OpticKind kind) {
    final name = '${ctx.clazz.name}${kind.opticName}Extension';
    final TypeParam generatedParam = kind.allCases(
      lens: ctx.newTypeParam.withBound(Type.from(ReifiedLenses.ThenLens)),
      getter: ctx.newTypeParam,
      mutater: ctx.newTypeParam,
    );
    final params = [generatedParam].followedBy(ctx.clazz.typeParams);
    final Type zoomFrom = kind.allCases(
      lens: ctx.newTypeParam,
      getter: Type('ThenGet', [ctx.newTypeParam]),
      mutater: Type('ThenMut', [ctx.newTypeParam]),
    );
    final on = Type('Zoom', [zoomFrom, ctx.clazz]);

    return 'extension $name${params.asDeclaration} on ${on} {';
  }

  void generateForElement(GeneratorContext ctx, ElementAnalogue elem,
      OpticKind kind, StringBuffer output) {
    Type zoomedType;
    if (elem is Field)
      zoomedType = elem.type;
    else if (elem is Getter)
      zoomedType = elem.returnType;
    else if (elem is Method)
      zoomedType = elem.returnType.value;
    else
      throw "unreachable";

    final generateOptic = (elem is Field && !elem.isStatic) || elem is Getter;
    final generatedOpticName = '_\$${elem.name}';
    if (generateOptic) {
      final staticType = kind.opticType(ctx.clazz, zoomedType);
      final staticField = Field(generatedOpticName,
          type: staticType, isStatic: true, isFinal: true);
      output.writeln(staticField.declaration(call(
        '${kind.opticName}.field',
        [
          "'${elem.name}'",
          if ([OpticKind.Lens, OpticKind.Getter].contains(kind))
            '(t) => t.${elem.name}',
          if ([OpticKind.Lens, OpticKind.Mutater].contains(kind))
            '(t, f) => t.copyWith(${elem.name}: f(t.${elem.name}))',
        ],
      )));
    }

    final thenArg =
        generateOptic ? generatedOpticName : '${ctx.clazz.name}.${elem.name}';
    final opticReturnType = zoom(ctx.newTypeParam, zoomedType);

    if (elem is Field || elem is Getter) {
      final getter = Getter(elem.name, opticReturnType);
      output.writeln(getter.declaration(call(kind.thenMethod, [thenArg])));
    } else if (elem is Method) {
      final method = Method(
        elem.name,
        typeParams: elem.typeParams,
        params: elem.params,
        returnType: Optional(opticReturnType),
      );

      final args = elem.params
          .where((e) => !e.isNamed)
          .map((e) => e.name)
          .followedBy(elem.params
              .where((e) => e.isNamed)
              .map((e) => '${e.name}: ${e.name}'));

      output.writeln(method.declaration(call(
        kind.thenMethod,
        [call(thenArg, args)],
      )));
    }
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

  Type opticType(Type source, Type target) =>
      zoom(Type(opticName, [source]), target);
}

Type zoom(Type source, Type target) => Type('Zoom', [source, target]);
