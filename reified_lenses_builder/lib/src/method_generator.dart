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
    final mutaters = clazz.methods.where((m) => m.name == mutaterName);
    final mutater = mutaters.isEmpty ? null : mutaters.first;
    final mutateds = clazz.methods.where((m) => m.name == '_${mutaterName}_mutated');
    final mutated = mutateds.isEmpty ? null : mutateds.first;

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
    final pathExpression = "[Vec<dynamic>(<dynamic>['${m.name}', ${m.params.asArgs()}])]";

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
              pathExpression,
              '($stateArg) => $getBody',
              if (parentKind == OpticKind.Lens) '($stateArg, $updateArg) => $mutBody',
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
                    (_obj) => DiffResult(
                      ${mutater!.invokeFromParams("_obj")},
                      ${mutated == null ? "Diff(changed: PathSet.from({$pathExpression}),)" : mutated.invokeFromParams("_obj")},
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
