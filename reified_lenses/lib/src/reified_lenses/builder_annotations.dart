library annotation;

enum OpticKind {
  Lens,
  Getter,
}

enum ReifiedKind {
  Primitive,
  Map,
  List,
  Struct,
  Union,
}

class ReifiedLens {
  final bool allFields;
  final ReifiedKind type;
  final Iterable<Type> cases;
  const ReifiedLens({
    this.allFields = true,
    this.cases = const [],
    this.type = ReifiedKind.Struct,
  });
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

class CopyWith {
  const CopyWith();
}

const copy_with = CopyWith();

class Undefined {
  const Undefined._();
}

const undefined = Undefined._();
