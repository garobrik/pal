import 'dart:core' as dart;
import 'dart:core';

abstract class TypeEnum {
  const TypeEnum();
}

extension Assignable on TypeEnum {
  bool assignableTo(TypeEnum other) => assignable(this, other);
}

bool assignable(TypeEnum a, TypeEnum b) {
  if (b is UnionType) {
    if (a is UnionType) {
      return a.types.every((aType) => b.types.any((bType) => aType.assignableTo(bType)));
    } else {
      return b.types.any((bType) => a.assignableTo(bType));
    }
  } else if (b is ListType) {
    return a is ListType && a.type.assignableTo(b.type);
  } else if (b is MapType) {
    return a is MapType && a.key.assignableTo(b.key) && a.value.assignableTo(b.value);
  } else {
    return a == b;
  }
}

class ListType extends TypeEnum {
  final TypeEnum type;

  const ListType(this.type);
}

class MapType extends TypeEnum {
  final TypeEnum key;
  final TypeEnum value;

  const MapType(this.key, this.value);
}

class UnionType extends TypeEnum {
  final dart.Set<TypeEnum> types;

  const UnionType(this.types) : assert(types.length > 1);
}

class UnionValue {
  final Type actualType;
  final Object value;

  const UnionValue(this.actualType, this.value);
}

class BooleanType extends TypeEnum {
  const BooleanType._();
}
const booleanType = BooleanType._();

class NumberType extends TypeEnum {
  const NumberType._();
}
const numberType = NumberType._();

class PlainTextType extends TypeEnum {
  const PlainTextType._();
}
const plainTextType = PlainTextType._();
