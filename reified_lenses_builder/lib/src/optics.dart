import 'package:reified_lenses/annotations.dart';

import 'parsing.dart';

class Optic {
  final OpticKind kind;
  final Iterable<AccessorPair> Function(Type Function(Type)) generateAccessors;
  final Iterable<Method> Function(Type Function(Type), OpticKind) generateMethods;

  const Optic({
    required this.kind,
    this.generateAccessors = _emptyAccessors,
    this.generateMethods = _emptyMethods,
  });
}

Iterable<AccessorPair> _emptyAccessors(Type Function(Type) wrapper) => const [];
Iterable<Method> _emptyMethods(Type Function(Type) wrapper, OpticKind kind) => const [];

extension OpticKindGeneration on OpticKind {
  A cases<A>({
    required A lens,
    required A getter,
  }) {
    switch (this) {
      case OpticKind.lens:
        return lens;
      case OpticKind.getter:
        return getter;
    }
  }

  String get thenMethod => this.cases(lens: 'then', getter: 'thenGet');

  String get opticName => this.cases(lens: 'Lens', getter: 'Getter');

  String get fieldCtor => opticName;
  String get ctor => opticName;
}
