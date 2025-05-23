import 'package:parse_generate/parse_generate.dart';

void generateMutations(StringBuffer output, Class clazz) {
  final potentialMutations = clazz.methods.where(
    (m) => (m.returnType?.typeEquals(clazz.type) ?? false) && m.name != 'mut_array_op',
  );
  final mutationMutateds = potentialMutations.expand<Pair<Method, Method>>((mutation) {
    final potentialPairs = clazz.methods.where((m) => m.name == '_${mutation.name}_mutated');
    if (potentialPairs.isEmpty) return [];
    final potentialPair = potentialPairs.first;
    assert(potentialPair.params.iterableEqual(mutation.params));
    assert(potentialPair.returnType!.typeEquals(const Type('PathSet')));
    return [Pair(mutation, potentialPair)];
  });
  if (mutationMutateds.isEmpty) return;

  Extension(
    '${clazz.name}Mutations',
    Type('Cursor', args: [clazz.type]),
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
          (obj) => DiffResult(
            ${mutation.invokeFromParams("obj")},
            ${mutated.invokeFromParams("obj")},
          ),
        );
      ''',
      );
    }),
  ).declare(output);
}
