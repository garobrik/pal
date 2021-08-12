library annotation;

import 'package:reified_lenses/reified_lenses.dart';

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

  static S? caseTo<T, S>(T t) => t is S ? t : null;
  static DiffResult<T> caseFrom<T, S extends T>(DiffResult<S> s) => s;
  static DiffResult<S?> caseUpdate<T, S>(T old, T nu, Diff diff) =>
      DiffResult(nu is S ? nu : null, diff);
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
