import 'parsing.dart';
import 'generating.dart';

void generateMutations(StringBuffer output, Class clazz) {
  final potentialMutations = clazz.methods.where((m) => m.returnType?.typeEquals(clazz) ?? false);
  final mutationMutateds = potentialMutations.expand<Pair<Method, Method>>((mutation) {
    final potentialPairs = clazz.methods.where((m) => m.name == '_${mutation.name}_mutated');
    if (potentialPairs.isEmpty) return [];
    final potentialPair = potentialPairs.first;
    assert(potentialPair.params.iterableEqual(mutation.params));
    assert(potentialPair.returnType!.typeEquals(Type('TrieSet', args: [Type.object])));
    return [Pair(mutation, potentialPair)];
  });
  if (mutationMutateds.isEmpty) return;

  final extension = Extension(
    '${clazz.name}Mutations',
    Type('Cursor', args: [clazz]),
    params: clazz.params,
    methods: mutationMutateds.map((mutationMutated) {
      final mutation = mutationMutated.first;
      final mutated = mutationMutated.second;
      return Method(
        mutation.name,
        params: mutation.params,
        typeParams: mutation.typeParams,
        body: '''
        mutResult(
          (_obj) => MutResult(
            ${mutation.invokeFromParams("_obj")},
            const [],
            ${mutated.invokeFromParams("_obj")},
          ),
        );
      ''',
      );
    }),
  ).declare(output);
}
