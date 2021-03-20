import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';
import 'generating.dart';
import 'optics.dart';

// TODO: handle multi-arg methods & method names
Iterable<Optic> generateMethodOptics(Class clazz) {
  return clazz.methods.expand((m) {
    if (!m.hasAnnotation(ReifiedLens) ||
        m.name == '==' ||
        m.name == 'toString' ||
        m.name.startsWith('mut_') ||
        m.isStatic ||
        m.returnType == null) return [];

    final isArrayOp = m.name == '[]';
    final mutaterName = isArrayOp ? 'mut_array_op' : 'mut_${m.name}';
    // ignore: unnecessary_cast, doesn't type check otherwise
    final mutater = (clazz.methods as Iterable<Method?>)
        .firstWhere((m) => m!.name == mutaterName, orElse: () => null);
    // ignore: unnecessary_cast, doesn't type check otherwise
    final mutated = (clazz.methods as Iterable<Method?>)
        .firstWhere((m) => m!.name == '_${mutaterName}_mutated', orElse: () => null);

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
    final getBody = m.invokeFromParams(stateArg, typeArgs: m.typeParams.map((tp) => tp.type));
    // TODO: this isFunctionalUpdate case can fail when a generic type has its argument cast upwards
    final mutBody = mutater?.invokeFromParams(
      stateArg,
      genArg: (p) => p != updateParam
          ? p.name
          : isFunctionalUpdate
              ? updateArg
              : '$updateArg($getBody)',
      typeArgs: m.typeParams.map((tp) => tp.type),
    );
    final mutatedBody = mutated?.invokeFromParams(
      stateArg,
      genArg: (p) => p != updateParam
          ? p.name
          : isFunctionalUpdate
              ? updateArg
              : '$updateArg($getBody)',
      typeArgs: m.typeParams.map((tp) => tp.type),
    );
    final pathExpression = "Vec<dynamic>(<dynamic>['${m.name}', ${m.params.asArgs()}])";

    print(isArrayOp);
    return [
      Optic(
        kind: kind,
        generateMethods: (wrapper, parentKind) {
          late final String body;
          if (mutatedBody == null) {
            body = call(parentKind.fieldCtor, [
              pathExpression,
              '($stateArg) => $getBody',
              if (parentKind == OpticKind.Lens) '($stateArg, $updateArg) => $mutBody',
            ]);
          } else {
            body = call(parentKind.ctor, [
              '($stateArg) => GetResult($getBody, [$pathExpression])',
              if (parentKind == OpticKind.Lens)
                '($stateArg, $updateArg) => MutResult($mutBody, [$pathExpression], $mutatedBody)',
            ]);
          }

          return [
            Method(
              m.name,
              returnType: wrapper(m.returnType!),
              isExpression: true,
              body: call(parentKind.thenMethod, [body]),
              params: m.params,
              typeParams: m.typeParams,
            ),
            if (isArrayOp && !isFunctionalUpdate && parentKind == OpticKind.Lens)
              Method(
                '[]=',
                typeParams: m.typeParams,
                params: [m.params.first, updateParam!],
                body: '''
                  mutResult(
                    (_obj) => MutResult(
                      ${mutater!.invokeFromParams("_obj")},
                      const [],
                      ${mutated == null ? "TrieSet.from({[$pathExpression]})" : mutated.invokeFromParams("_obj")},
                    ),
                  );
                ''',
              )
          ];
        },
      )
    ];
  });
}
