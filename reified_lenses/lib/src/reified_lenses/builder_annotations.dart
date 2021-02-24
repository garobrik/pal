library annotation;

enum OpticKind {
  Lens,
  Getter,
}

class Optic {
  final OpticKind kind;
  const Optic._({required this.kind});
}

const lens = Optic._(kind: OpticKind.Lens);
const getter = Optic._(kind: OpticKind.Getter);

class ReifiedLens {
  final bool allFields;
  final Iterable<Type> cases;
  const ReifiedLens({this.allFields = true, this.cases = const []});
}

const reify = ReifiedLens();

class Skip {
  const Skip();
}

const skip = Skip();

class CopyConstructor {
  const CopyConstructor();
}

const copy_constructor = CopyConstructor();
