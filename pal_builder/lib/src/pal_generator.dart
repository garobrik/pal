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
    final output = StringBuffer();

    final dartFns = [
      for (final fn in library.element.units.expand((cu) => cu.functions))
        if (fn.hasAnnotation(DartFn)) TopLevelFunction.fromElement(library.element, fn),
    ];

    if (dartFns.isEmpty) return '';

    final prefix = library.element.source.shortName
        .substring(0, library.element.source.shortName.indexOf('.'))
        .replaceAllMapped(RegExp(r'_([a-z])'), (match) => match[1]!.toUpperCase());

    output.writeln('FnMap ${prefix}FnMap = {');
    for (final fn in dartFns) {
      final annotation = fn.getAnnotation(DartFn)!;
      final id = annotation.read('id').stringValue;
      final label = annotation.read('label').isNull
          ? ''
          : 'label: \'${annotation.read('label').stringValue}\', ';
      final hashCode = Object.hash(id, null);

      output.writeln('const ID.constant(id: \'$id\', $label hashCode: $hashCode): ${fn.name},');
    }
    output.writeln('};');

    output.writeln('const InverseFnMap ${prefix}InverseFnMap = {');
    for (final fn in dartFns) {
      final annotation = fn.getAnnotation(DartFn)!;
      final id = annotation.read('id').stringValue;
      final label = annotation.read('label').isNull
          ? ''
          : 'label: \'${annotation.read('label').stringValue}\', ';
      final hashCode = Object.hash(id, null);

      output.writeln('${fn.name}: ID.constant(id: \'$id\', $label hashCode: $hashCode),');
    }
    output.writeln('};');

    return output.toString();
  }
}
