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
        library.annotatedWith(TypeChecker.fromRuntime(ReaderWidgetAnnotation)).where((elem) {
      if (elem.element is FunctionElement) return true;
      log.warning(
          '@reader_widget annotation can only be applied to methods, was applied to ${elem.element.logString}.');
      return false;
    });

    if (boundWidgetElements.isEmpty) return output.toString();

    final resolveType = (String uri, String name) async {
      final libraryElement = await buildStep.resolver.libraryFor(
        AssetId.resolve(Uri.parse(uri), from: buildStep.inputId),
      );
      final element = libraryElement.exportNamespace.get(name);
      if (element is! ClassElement) {
        throw UnresolvableTypeException(uri, name);
      }
      return Type.fromDartType(library.element, element.thisType);
    };

    final resolvedTypes = _ResolvedTypes(
      buildContext: await resolveType('package:flutter/widgets.dart', 'BuildContext'),
      key: await resolveType('package:flutter/widgets.dart', 'Key'),
      getCursor: await resolveType('package:reified_lenses/reified_lenses.dart', 'GetCursor'),
      reader: await resolveType('package:reified_lenses/reified_lenses.dart', 'Reader'),
    );

    for (final annotated in boundWidgetElements) {
      generateBoundWidget(
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
  final Type reader;

  _ResolvedTypes({
    required this.buildContext,
    required this.key,
    required this.getCursor,
    required this.reader,
  });
}

void generateBoundWidget(StringBuffer output, _ResolvedTypes resolvedTypes, FunctionDefinition function) {
  final offset = function.name.startsWith('_') ? 1 : 0;
  final name = function.name.substring(offset, offset + 1).toUpperCase() +
      function.name.substring(offset + 1);
  final buildContextParam =
      firstOfNameAndType(function.params, 'context', resolvedTypes.buildContext);
  final keyParam = firstOfNameAndType(function.params, 'key', resolvedTypes.key);
  final readerParam = firstOfNameAndType(function.params, 'reader', resolvedTypes.reader);
  final nonSpecialParams =
      function.params.where((p) => p != buildContextParam && p != keyParam && p != readerParam);
  final buildBody = StringBuffer();
  if (readerParam != null) {
    buildBody.writeln('final ${readerParam.name} = useCursorReader();');
  }
  final returnValue = function.invokeFromParams(typeArgs: function.typeParams.map((tp) => tp.type));
  buildBody.writeln('return $returnValue;');

  Class(
    name,
    params: function.typeParams,
    extendedType: Type('HookWidget'),
    constructors: (clazz) => [
      Constructor(
        parent: clazz,
        isConst: true,
        params: [
          for (final param in nonSpecialParams) param.copyWith(isInitializingFormal: true),
          Param(resolvedTypes.key.withNullable(true), 'key', isNamed: true, isRequired: false),
        ],
        initializers: 'super(key: key)',
      ),
    ],
    fields: nonSpecialParams.map((p) => Field(p.name, type: p.type, isFinal: true)),
    methods: [
      Method(
        'build',
        annotations: ['@override'],
        returnType: Type('Widget'),
        params: [buildContextParam ?? Param(Type('BuildContext'), 'context')],
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
