import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';

Class maybeGenerateSerialization(
  StringBuffer output,
  Class clazz,
  Iterable<Param> copyWithParams,
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
            case ReifiedKind.Primitive:
              return 'return toString();';
            case ReifiedKind.Map:
              return '''
                return List<Map<String, dynamic>>.from(
                  this.entries.map<Map<String, dynamic>>(
                    (entry) => <String, dynamic>{
                      'key': ${checkedToJsonCall('entry.key')},
                      'value': ${checkedToJsonCall('entry.value')},
                    },
                  ),
                );
              ''';
            case ReifiedKind.List:
              return '''
                return List<dynamic>.from(
                  this.map<dynamic>((entry) => ${checkedToJsonCall('entry')}),
                );
              ''';
            case ReifiedKind.Struct:
              final generatedMap = map({
                for (final param in copyWithParams)
                  "'${param.name}'": checkedToJsonCall('this.${param.name}'),
              });
              return 'return <String, dynamic>$generatedMap;';
            case ReifiedKind.Union:
              return null;
          }
        }(),
      ),
      if (kind == ReifiedKind.List)
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
      if (kind == ReifiedKind.Map)
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

String checkedToJsonCall(String arg) => '''
      ($arg is num || $arg is String || $arg is bool || $arg == null || $arg is List || $arg is Map<String, dynamic>)
        ? $arg
        : ($arg as dynamic).toJson()
    ''';
