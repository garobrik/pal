library annotation;

import 'package:meta/meta.dart';

enum OpticKind {
  Lens,
  Getter,
  Mutater,
}

class Optic {
  // index into [OpticKind]
  final int kind;
  const Optic._({@required this.kind});
}

const lens = Optic._(kind: 0);
const getter = Optic._(kind: 1);
const mutater = Optic._(kind: 2);

class ReifiedLens {
  final bool allFields;
  const ReifiedLens({this.allFields = true});
}

const reified_lens = ReifiedLens();

class SkipLens {
  const SkipLens();
}

const skip_lens = SkipLens();

class CopyConstructor {
  const CopyConstructor();
}

const copy_constructor = CopyConstructor();
