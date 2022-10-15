import 'package:analyzer/dart/element/type.dart' as analyzer;
import 'package:reified_lenses/annotations.dart';

import 'package:parse_generate/parse_generate.dart';

Class maybeGenerateSerialization(
  StringBuffer output,
  Class clazz,
  Iterable<Field> copyWithParams,
) {
  final kind = ReifiedKind.values.elementAt(
    clazz.getAnnotation(ReifiedLens)!.read('type').objectValue.getField('index')!.toIntValue()!,
  );

  return Class(
    clazz.isPrivate ? '${clazz.name}Mixin' : '_${clazz.name}Mixin',
    isAbstract: true,
    params: clazz.params,
    methods: [
      Method(
        'toJson',
        returnType: Type.dynamic,
        isExpression: false,
        body: () {
          switch (kind) {
            case ReifiedKind.primitive:
              return 'return toString();';
            case ReifiedKind.map:
              return '''
                bool allString = true;
                final toJsonEntries = this.entries.map(
                  (entry) {
                  dynamic key = ${checkedToJsonCall(clazz.params.first.extendz, 'entry.key')};
                  dynamic value = ${checkedToJsonCall(clazz.params.elementAt(1).extendz, 'entry.value')};
                  if (key is num) {
                    key = key.toString();
                  }
                  if (key is! String) {
                    allString = false;
                  }
                  return MapEntry<dynamic, dynamic>(key, value);
                } ,
                );
                if (allString) {
                  return Map<dynamic, dynamic>.fromEntries(toJsonEntries);
                } else {
                  return List<Map<String, dynamic>>.from(
                    toJsonEntries.map<Map<String, dynamic>>(
                      (entry) => <String, dynamic>{
                        'key': entry.key,
                        'value': entry.value,
                      },
                    ),
                  );
                }
              ''';
            case ReifiedKind.list:
              return '''
                return List<dynamic>.from(
                  this.map<dynamic>((entry) => ${checkedToJsonCall(clazz.params.first.extendz, 'entry')}),
                );
              ''';
            case ReifiedKind.struct:
              final generatedMap = map({
                for (final param in copyWithParams)
                  "'${param.name}'": checkedToJsonCall(param.type, 'this.${param.name}'),
              });
              return 'return <String, dynamic>$generatedMap;';
            case ReifiedKind.union:
              return null;
          }
        }(),
      ),
      if (kind == ReifiedKind.list)
        Method(
          'map',
          returnType: Type('Iterable', args: [clazz.newTypeParams(1).first.type]),
          typeParams: clazz.newTypeParams(1),
          params: [
            Param(
              FunctionType(
                returnType: clazz.newTypeParams(1).first.type,
                requiredArgs: [clazz.params.first.type],
              ),
              'f',
            )
          ],
        ),
    ],
    accessors: [
      if (kind == ReifiedKind.map)
        AccessorPair(
          'entries',
          getter: Getter(
            'entries',
            Type(
              'Iterable',
              args: [Type('MapEntry', args: clazz.params.map((tp) => tp.type))],
            ),
          ),
        ),
    ],
  );
}

String checkedToJsonCall(Type? type, String arg) {
  late final fullDynamicCheck = '''
      ($arg is num || $arg is String || $arg is bool || $arg == null || $arg is List || $arg is Map<String, dynamic>)
        ? $arg
        : ($arg as dynamic).toJson()
    ''';
  if (type == null || type.dartType == null) {
    return fullDynamicCheck;
  }
  final dartType = type.dartType!;
  if (dartType.isDartCoreBool ||
      dartType.isDartCoreNum ||
      dartType.isDartCoreString ||
      dartType.isDartCoreList) {
    return arg;
  }

  final element = (dartType is analyzer.InterfaceType)
      ? dartType.element2
      : dartType is analyzer.TypeParameterType
          ? dartType.element2
          : null;
  final typeSystem = element?.library?.typeSystem;
  final typeProvider = element?.library?.typeProvider;
  if (typeSystem == null || typeProvider == null) {
    return fullDynamicCheck;
  }

  final mapType = typeProvider.mapType(typeProvider.stringType, typeProvider.dynamicType);

  if (typeSystem.isSubtypeOf(dartType, mapType)) {
    return arg;
  }

  if (typeSystem.isPotentiallyNullable(dartType)) {
    return '$arg == null ? null : ($arg as dynamic).toJson()';
  } else {
    return '($arg as dynamic).toJson()';
  }
}
