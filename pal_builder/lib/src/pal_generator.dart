import 'dart:async';
import 'dart:core' as core;
import 'dart:core';

import 'package:build/build.dart';
import 'package:parse_generate/parse_generate.dart';
import 'package:source_gen/source_gen.dart';
import 'package:knose/annotations.dart';

class PalGenerator extends Generator {
  const PalGenerator();

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    final dartFns = <ElementAnalogue>[
      for (final fn in library.element.units.expand((cu) => cu.functions))
        if (fn.hasAnnotation(DartFn)) TopLevelFunction.fromElement(library.element, fn),
      for (final fn in library.element.units
          .expand((cu) => cu.classes)
          .expand((cl) => cl.methods)
          .where((m) => m.isStatic))
        if (fn.hasAnnotation(DartFn)) Method.fromElement(library.element, fn),
    ];

    if (dartFns.isEmpty) return '';

    final prefix = library.element.source.shortName
        .substring(0, library.element.source.shortName.indexOf('.'))
        .replaceAllMapped(RegExp(r'_([a-z])'), (match) => match[1]!.toUpperCase());

    String qualifiedFnName(ElementAnalogue fn) {
      if (fn is TopLevelFunction) {
        return fn.name;
      } else if (fn is Method) {
        return '${fn.element!.enclosingElement3.name!}.${fn.name}';
      } else {
        throw UnimplementedError();
      }
    }

    final fnMapOutput = StringBuffer();
    final inverseMapOutput = StringBuffer();
    fnMapOutput.writeln('FnMap ${prefix}FnMap = {');
    inverseMapOutput.writeln('InverseFnMap ${prefix}InverseFnMap = {');
    for (final fn in dartFns) {
      final annotation = fn.getAnnotation(DartFn)!;
      final id = annotation.read('id').stringValue;
      final label =
          annotation.read('label').isNull ? fn.name : annotation.read('label').stringValue;
      final hashCode = Object.hash(id, null);

      final idString = 'const ID.constant(id: \'$id\', label: \'$label\', hashCode: $hashCode)';
      final fnString = qualifiedFnName(fn);
      fnMapOutput.writeln('$idString: $fnString,');
      inverseMapOutput.writeln('$fnString: $idString,');
    }
    fnMapOutput.writeln('};');
    inverseMapOutput.writeln('};');

    return '$fnMapOutput\n$inverseMapOutput';
  }
}
