import 'dart:async';
import 'dart:core';

import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:flutter_reified_lenses/flutter_annotations.dart';
import 'package:source_gen/source_gen.dart';
import 'parsing.dart';
import 'parsing.dart' as parsing;
import 'generating.dart';

class FlutterReifiedLensesGenerator extends Generator {
  const FlutterReifiedLensesGenerator();

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    final output = StringBuffer();

    final boundWidgetElements =
        library.annotatedWith(const TypeChecker.fromRuntime(ReaderWidgetAnnotation)).where((elem) {
      if (elem.element is FunctionElement) return true;
      log.warning(
          '@reader_widget annotation can only be applied to methods, was applied to ${elem.element.logString}.');
      return false;
    });

    if (boundWidgetElements.isEmpty) return output.toString();

    Future<Type> resolveType(String uri, String name) async {
      final libraryElement = await buildStep.resolver.libraryFor(
        AssetId.resolve(Uri.parse(uri), from: buildStep.inputId),
      );
      final element = libraryElement.exportNamespace.get(name);
      if (element is! ClassElement) {
        throw UnresolvableTypeException(uri, name);
      }
      return Type.fromDartType(library.element, element.thisType);
    }

    final resolvedTypes = _ResolvedTypes(
      buildContext: await resolveType('package:flutter/widgets.dart', 'BuildContext'),
      key: await resolveType('package:flutter/widgets.dart', 'Key'),
      getCursor: await resolveType('package:reified_lenses/reified_lenses.dart', 'GetCursor'),
      ctx: await resolveType('package:ctx/ctx.dart', 'Ctx'),
    );

    for (final annotated in boundWidgetElements) {
      _generateBoundWidget(
        output,
        resolvedTypes,
        FunctionDefinition.fromElement(library.element, annotated.element as FunctionElement),
      );
    }

    return output.toString();
  }
}

class _ResolvedTypes {
  final Type buildContext;
  final Type key;
  final Type getCursor;
  final Type ctx;

  _ResolvedTypes({
    required this.buildContext,
    required this.key,
    required this.getCursor,
    required this.ctx,
  });
}

void _generateBoundWidget(
    StringBuffer output, _ResolvedTypes resolvedTypes, FunctionDefinition function) {
  final offset = function.name.startsWith('_') ? 1 : 0;
  final name = function.name.substring(offset, offset + 1).toUpperCase() +
      function.name.substring(offset + 1);
  final buildContextParam =
      firstOfNameAndType(function.params, 'context', resolvedTypes.buildContext);
  final keyParam = firstOfNameAndType(function.params, 'key', resolvedTypes.key);
  final ctxParam = firstOfNameAndType(function.params, 'ctx', resolvedTypes.ctx);
  final nonSpecialParams = function.params.where((p) => p != buildContextParam && p != keyParam);
  final buildBody = StringBuffer();
  if (ctxParam != null) {
    buildBody.writeln('final ${ctxParam.name} = useCursorReader(this.${ctxParam.name});');
  }
  final returnValue = function.invokeFromParams(typeArgs: function.typeParams.map((tp) => tp.type));
  buildBody.writeln('return $returnValue;');

  final ctorParams = [
    for (final param in nonSpecialParams) param.copyWith(isInitializingFormal: true),
    Param(resolvedTypes.key.withNullable(true), 'key', isNamed: true, isRequired: false),
  ];

  Class(
    name,
    params: function.typeParams,
    extendedType: const Type('HookWidget'),
    constructors: (clazz) => [
      Constructor(
        parent: clazz,
        isConst: true,
        params: ctorParams,
        initializers: 'super(key: key)',
      ),
    ],
    fields: nonSpecialParams.map((p) => Field(p.name, type: p.type, isFinal: true)),
    methods: [
      Method(
        'build',
        annotations: const ['@override'],
        returnType: const Type('Widget'),
        params: [buildContextParam ?? const Param(Type('BuildContext'), 'context')],
        body: buildBody.toString(),
      ),
    ],
  ).declare(output);
}

Param? firstOfNameAndType(Iterable<Param> params, String name, Type type) {
  final firstOfName = params.maybeFirstWhere((p) => p.name == name);
  if (firstOfName == null) return null;
  if (firstOfName.type.dartType!.isAssignableTo(type)) {
    return firstOfName;
  }
  return null;
}

extension AssignableTo on DartType {
  bool isAssignableTo(Type type) =>
      TypeChecker.fromStatic(type.dartType!).isAssignableFromType(this);
}
