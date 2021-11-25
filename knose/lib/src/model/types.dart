import 'dart:core' as dart;
import 'dart:core';

import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart';

part 'types.g.dart';

class TypeID extends PalID<InterfaceDef> {
  static const namespace = 'PalType';

  TypeID.create() : super.create(namespace: namespace);
  TypeID.from(String key) : super.from(namespace, key);
}

class ImplID extends PalID<PalImpl> {
  static const namespace = 'PalImpl';

  ImplID.create() : super.create(namespace: namespace);
  ImplID.from(String key) : super.from(namespace, key);
}

abstract class PalType {
  const PalType();
}

@reify
class PalValue extends PalType with _PalValueMixin implements PalExpr {
  @override
  final PalType type;
  @override
  final Object value;

  const PalValue(this.type, this.value);
}

extension Assignable on PalType {
  bool assignableTo(Ctx ctx, PalType other) {
    return assignable(ctx, this, other);
  }
}

bool assignable(Ctx ctx, PalType a, PalType b) {
  if (b is AnyType || b is TypeType || b is UnitType) {
    return true;
  } else if (a is UnionType) {
    return a.types.every((aType) => aType.assignableTo(ctx, b));
  } else if (b is UnionType) {
    return b.types.any((bType) => a.assignableTo(ctx, bType));
  } else if (b is IntersectionType) {
    return b.types.every((bType) => a.assignableTo(ctx, bType));
  } else if (a is IntersectionType) {
    return a.types.any((aType) => aType.assignableTo(ctx, b));
  } else if (b is ListType) {
    if (a is ListType) {
      return a.type.assignableTo(ctx, b.type);
    } else if (a is PalValue) {
      if (a.type is! ListType) return false;
      for (final value in a.value as dart.List<PalType>) {
        if (!value.assignableTo(ctx, b.type)) return false;
      }
      return true;
    } else {
      return false;
    }
  } else if (b is MapType) {
    if (a is MapType) {
      return a.key.assignableTo(ctx, b.key) && a.value.assignableTo(ctx, b.value);
    } else if (a is PalValue) {
      if (a.type is! MapType) return false;
      for (final entry in (a.value as Map<PalValue, PalType>).entries) {
        if (!entry.key.type.assignableTo(ctx, b.key)) return false;
        if (!entry.value.assignableTo(ctx, b.value)) return false;
      }
      return true;
    } else {
      return false;
    }
  } else if (b is FunctionType) {
    if (a is! FunctionType) return false;
    if (!a.returnType.assignableTo(ctx, b.returnType)) {
      return false;
    }

    return b.target.assignableTo(ctx, a.target);
  } else if (b is InterfaceType) {
    if (a is InterfaceType && a.id == b.id) {
      if (b.assignments.entries.every((entry) => a.assignments[entry.key] == entry.value)) {
        return true;
      }
    }

    final implementation = ctx.db.find<PalImpl>(
      ctx: ctx,
      namespace: ImplID.namespace,
      predicate: (impl) {
        final implementer = impl.implementer.read(ctx);
        if (!a.assignableTo(ctx, implementer)) return false;
        return impl.implemented.read(ctx).assignableTo(ctx, b);
      },
    );
    return implementation.unwrap != null;
  } else if (b is PalValue) {
    if (a is! PalValue) return false;
    if (!a.type.assignableTo(ctx, b.type)) return false;
    if (b.type is MapType) {
      if (a.type is! MapType) return false;
      final aMap = a.value as dart.Map<PalValue, PalType>;
      final bMap = b.value as dart.Map<PalValue, PalType>;
      if (aMap.length != bMap.length) return false;
      for (final entry in aMap.entries) {
        final bValue = bMap[entry.key];
        if (bValue == null) return false;
        if (!entry.value.assignableTo(ctx, bValue)) return false;
      }
      return true;
    } else if (b.type is ListType) {
      if (a.type is! ListType) return false;
      final aList = a.value as dart.List<PalType>;
      final bList = b.value as dart.List<PalType>;
      if (aList.length != bList.length) return false;
      for (final pair in zip(aList, bList)) {
        if (!pair.first.assignableTo(ctx, pair.second)) return false;
      }
      return true;
    } else {
      return a.value == b.value;
    }
  } else {
    if (a is PalValue) return a.type == b;
    return a == b;
  }
}

class AnyType extends PalType {
  const AnyType._();
  @override
  String toString() => 'Any';
}

const anyType = AnyType._();

class ListType extends PalType {
  final PalType type;

  const ListType(this.type);

  @override
  String toString() => 'List($type)';
}

class MapType extends PalType {
  final PalType key;
  final PalType value;

  const MapType(this.key, this.value);

  @override
  String toString() => 'Map($key, $value)';
}

class UnionType extends PalType {
  final dart.Set<PalType> types;

  const UnionType(this.types) : assert(types.length > 1);

  @override
  String toString() => 'Union(${types.join(", ")})';
}

class IntersectionType extends PalType {
  final dart.Set<PalType> types;

  const IntersectionType(this.types) : assert(types.length > 1);

  @override
  String toString() => 'Intersection(${types.join(", ")})';
}

class BooleanType extends PalType {
  const BooleanType._();

  @override
  String toString() => 'Boolean';
}

const booleanType = BooleanType._();

class NumberType extends PalType {
  const NumberType._();

  @override
  String toString() => 'Number';
}

const numberType = NumberType._();

class TextType extends PalType {
  const TextType._();

  @override
  String toString() => 'Text';
}

const textType = TextType._();

class TypeType extends PalType {
  const TypeType._();

  @override
  String toString() => 'Type';
}

const typeType = TypeType._();

class UnitType extends PalType {
  const UnitType._();

  @override
  String toString() => 'Unit';
}

const unitType = UnitType._();

class FunctionType extends PalType {
  final PalType target;
  final PalType returnType;

  const FunctionType({
    this.target = unitType,
    this.returnType = unitType,
  });

  @override
  String toString() => '($target) => $returnType';
}

class InterfaceType extends PalType {
  final TypeID id;
  final Map<MemberID, PalType> assignments;

  InterfaceType({required this.id, this.assignments = const {}});

  @override
  String toString() => 'Interface($id)';
}

class MemberID extends UUID<MemberID> {}

class InterfaceDef {
  final TypeID id;
  final String name;
  final Map<MemberID, PalMember> members;

  InterfaceDef({
    TypeID? id,
    required this.name,
    required dart.List<PalMember> members,
  })  : this.id = id ?? TypeID.create(),
        members = {for (final member in members) member.id: member};

  InterfaceType asType([Map<MemberID, PalType> assignments = const {}]) =>
      InterfaceType(id: id, assignments: assignments);
}

class PalMember {
  final MemberID id;
  final String name;
  final PalType type;

  PalMember({MemberID? id, required this.name, required this.type}) : id = id ?? MemberID();
}

@reify
class PalImpl with _PalImplMixin {
  @override
  final TypeID id;
  @override
  final PalType implementer;
  @override
  final InterfaceType implemented;
  @override
  final Map<MemberID, PalExpr> implementations;

  PalImpl({
    TypeID? id,
    required this.implementer,
    required this.implemented,
    required this.implementations,
  }) : this.id = id ?? TypeID.create();
}

abstract class PalExpr extends PalType {
  const PalExpr();
}

class MemberAccess extends PalExpr {
  final MemberID accessedMember;

  MemberAccess(this.accessedMember);
}

extension PalValueCursorExtensions on Cursor<PalValue> {
  Cursor<V> mapAccess<K extends Object, V>(K key) {
    return value.cast<Dict<K, V>>()[key].whenPresent;
  }

  Cursor<V> recordAccess<V extends Object>(String key) {
    return value.cast<Dict<String, Object>>()[key].whenPresent.cast<V>();
  }
}

extension PalValueExtensions on PalValue {
  V recordAccess<V>(String key) {
    return (value as Dict<String, Object>)[key].unwrap! as V;
  }
}
