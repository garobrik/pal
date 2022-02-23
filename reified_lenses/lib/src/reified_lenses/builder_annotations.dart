library annotation;

enum OpticKind {
  lens,
  getter,
}

enum ReifiedKind {
  primitive,
  map,
  list,
  struct,
  union,
}

class GetterAnnotation {
  const GetterAnnotation();
}

const getter = GetterAnnotation();

class ReifiedLens {
  final bool allFields;
  final ReifiedKind type;
  final Iterable<Type> cases;
  const ReifiedLens({
    this.allFields = true,
    this.cases = const [],
    this.type = ReifiedKind.struct,
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

const copyConstructor = CopyConstructor();

class CopyWith {
  const CopyWith();
}

const copyWith = CopyWith();

class Undefined {
  const Undefined._();
}

const undefined = Undefined._();
