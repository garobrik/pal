import 'dart:core' as dart;
import 'dart:core';
import 'package:meta/meta.dart';

import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart';

part 'types.g.dart';

class ImplID extends PalID<PalImpl> {
  static const namespace = 'PalImpl';

  ImplID.create() : super.create(namespace: namespace);
  ImplID.from(String key) : super.from(namespace, key);
}

abstract class PalType {
  const PalType();

  bool get isConcrete;
}

@reify
class PalValue extends PalType with _PalValueMixin implements PalExpr {
  @override
  final PalType type;
  @override
  final Object value;

  const PalValue(this.type, this.value);

  @override
  PalType evalType(Ctx ctx) => type;

  @override
  Object eval(Ctx ctx) {
    if (type == typeType) {
      if (value is DataType) {
        return DataType(
          id: (value as DataType).id,
          assignments: (value as DataType).assignments.map(
                (key, value) => MapEntry(
                  key,
                  value is PalExpr ? value.eval(ctx) as PalType : value,
                ),
              ),
        );
      }
    }
    return value;
  }

  @override
  String toString() => 'PalValue($value: $type)';

  @override
  bool get isConcrete => type.isConcrete;
}

extension WrapValueExtension<T extends Object> on Cursor<T> {
  Cursor<PalValue> wrap(PalType type) {
    return partial(
      to: (object) => PalValue(type, object),
      from: (diff) => DiffResult(diff.value.value as T, diff.diff.atPrefix(['value'])),
      update: (old, nu, diff) => DiffResult(PalValue(type, nu), diff.prepend(['value'])),
    );
  }
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
  } else if (a is PalExpr) {
    return (a.eval(ctx) as PalType).assignableTo(ctx, b);
  } else if (b is PalExpr) {
    return a.assignableTo(ctx, b.eval(ctx) as PalType);
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
  } else if (b is DataType) {
    if (a is DataType && a.id == b.id) {
      if (b.assignments.entries.every((entry) => a.assignments[entry.key] == entry.value)) {
        return true;
      }
    }
    return false;
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
  } else if (a is PalValue) {
    return a.type.assignableTo(ctx, b);
  } else {
    return a == b;
  }
}

class AnyType extends PalType {
  const AnyType._();
  @override
  String toString() => 'Any';

  @override
  bool get isConcrete => false;
}

const anyType = AnyType._();

class ThisType extends PalType {
  const ThisType._();

  @override
  String toString() => 'This';

  @override
  bool get isConcrete => false;
}

const thisType = ThisType._();

class ListType extends PalType {
  final PalType type;

  const ListType(this.type);

  @override
  String toString() => 'List($type)';

  @override
  bool get isConcrete => true;
}

@reify
class MapType extends PalType with _MapTypeMixin {
  @override
  final PalType key;
  @override
  final PalType value;

  const MapType(this.key, this.value);

  @override
  String toString() => 'Map($key, $value)';

  @override
  bool get isConcrete => true;
}

class UnionType extends PalType {
  final dart.Set<PalType> types;

  const UnionType(this.types) : assert(types.length > 1);

  @override
  String toString() => 'Union(${types.join(", ")})';

  @override
  bool get isConcrete => false;
}

class IntersectionType extends PalType {
  final dart.Set<PalType> types;

  const IntersectionType(this.types) : assert(types.length > 1);

  @override
  String toString() => 'Intersection(${types.join(", ")})';

  @override
  bool get isConcrete => false;
}

class BooleanType extends PalType {
  const BooleanType._();

  @override
  String toString() => 'Boolean';

  @override
  bool get isConcrete => true;
}

const booleanType = BooleanType._();

class NumberType extends PalType {
  const NumberType._();

  @override
  String toString() => 'Number';

  @override
  bool get isConcrete => true;
}

const numberType = NumberType._();

class TextType extends PalType {
  const TextType._();

  @override
  String toString() => 'Text';

  @override
  bool get isConcrete => true;
}

const textType = TextType._();

class TypeType extends PalType {
  const TypeType._();

  @override
  String toString() => 'Type';

  @override
  bool get isConcrete => true;
}

const typeType = TypeType._();

class UnitType extends PalType {
  const UnitType._();

  @override
  String toString() => 'Unit';

  @override
  bool get isConcrete => true;
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

  @override
  bool get isConcrete => true;
}

class MemberID extends UUID<MemberID> {}

class InterfaceType extends PalType {
  final InterfaceID id;
  final Map<MemberID, PalType> assignments;

  InterfaceType({required this.id, this.assignments = const {}});

  @override
  String toString() => 'Interface($id)';

  @override
  bool get isConcrete => false;
}

class InterfaceID extends PalID<InterfaceDef> {
  static const namespace = 'PalInterface';

  InterfaceID.create() : super.create(namespace: namespace);
  InterfaceID.from(String key) : super.from(namespace, key);
}

class InterfaceDef {
  final InterfaceID id;
  final String name;
  final Map<MemberID, PalMember> members;

  InterfaceDef({
    InterfaceID? id,
    required this.name,
    required dart.List<PalMember> members,
  })  : this.id = id ?? InterfaceID.create(),
        members = {for (final member in members) member.id: member};

  InterfaceType asType([Map<MemberID, PalType> assignments = const {}]) =>
      InterfaceType(id: id, assignments: assignments);
}

class DataType extends PalType {
  final DataID id;
  final Map<MemberID, PalType> assignments;

  DataType({required this.id, this.assignments = const {}});

  @override
  bool get isConcrete => true;
}

class DataID extends PalID<DataDef> {
  static const namespace = 'PalData';

  DataID.create() : super.create(namespace: namespace);
  DataID.from(String key) : super.from(namespace, key);
}

class DataDef {
  final DataID id;
  final String name;
  final DataTree<PalType> tree;

  DataDef.record({
    DataID? id,
    required this.name,
    required dart.List<PalMember> members,
  })  : this.id = id ?? DataID.create(),
        tree = RecordNode({
          for (final member in members)
            member.id: DataTreeElement(member.name, LeafNode(member.type)),
        });

  DataDef.union({
    DataID? id,
    required this.name,
    required dart.List<PalMember> members,
  })  : this.id = id ?? DataID.create(),
        tree = UnionNode({
          for (final member in members)
            member.id: DataTreeElement(member.name, LeafNode(member.type)),
        });

  DataDef({
    DataID? id,
    required this.name,
    required this.tree,
  }) : this.id = id ?? DataID.create();

  DataType asType([Map<MemberID, PalType> assignments = const {}]) =>
      DataType(id: id, assignments: assignments);
}

@sealed
abstract class DataTree<T> {
  const DataTree();
}

class UnionNode<T> extends DataTree<T> {
  final Map<MemberID, DataTreeElement<T>> elements;

  const UnionNode(this.elements);
}

class RecordNode<T> extends DataTree<T> {
  final Map<MemberID, DataTreeElement<T>> elements;

  RecordNode(this.elements);
}

class DataTreeElement<T> {
  final String name;
  final DataTree<T> node;

  const DataTreeElement(this.name, this.node);
}

class LeafNode<T> extends DataTree<T> {
  final T type;

  LeafNode(this.type);
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
  final ImplID id;
  @override
  final PalType implementer;
  @override
  final InterfaceType implemented;
  @override
  final Map<MemberID, PalExpr> implementations;

  PalImpl({
    ImplID? id,
    required this.implementer,
    required this.implemented,
    required this.implementations,
  }) : this.id = id ?? ImplID.create();
}

abstract class PalExpr extends PalType {
  const PalExpr();

  PalType evalType(Ctx ctx);
  Object eval(Ctx ctx);

  @override
  bool get isConcrete => false;
}

class ThisExpr extends PalExpr {
  const ThisExpr._();

  @override
  PalType evalType(Ctx ctx) => ctx.thisValue.type;

  @override
  Object eval(Ctx ctx) => ctx.thisValue.value;
}

extension _ThisCtxExtension on Ctx {
  PalValue get thisValue => get<_ThisCtx>()!.thisCtx;
  Ctx withThis(PalValue value) => withElement(_ThisCtx(value));
}

class _ThisCtx extends CtxElement {
  final PalValue thisCtx;

  const _ThisCtx(this.thisCtx);
}

const thisExpr = ThisExpr._();

class InterfaceAccess extends PalExpr {
  final PalExpr target;
  final InterfaceType iface;
  final MemberID member;

  InterfaceAccess({
    required this.member,
    this.target = thisExpr,
    required this.iface,
  });

  @override
  PalType evalType(Ctx ctx) {
    {
      final assignment = iface.assignments[member];
      if (assignment != null) {
        return assignment;
      }
    }
    return ctx.db.get(iface.id).whenPresent.read(ctx).members[member]!.type;
  }

  @override
  Object eval(Ctx ctx) {
    final targetType = target.evalType(ctx);
    final targetValue = target.eval(ctx);
    assert(targetType.assignableTo(ctx, iface));
    final impl = findImpl(ctx, targetType, iface);
    assert(impl != null);
    return impl!.implementations[member]!.eval(ctx.withThis(PalValue(targetType, targetValue)));
  }
}

class RecordAccess extends PalExpr {
  final PalExpr target;
  final MemberID member;

  RecordAccess(this.member, {this.target = thisExpr});

  @override
  PalType evalType(Ctx ctx) {
    final targetType = target.evalType(ctx) as DataType;
    if (targetType.assignments.containsKey(member)) {
      return targetType.assignments[member]!;
    }
    return ((ctx.db.get(targetType.id).whenPresent.read(ctx).tree as RecordNode<PalType>)
            .elements[member]!
            .node as LeafNode<PalType>)
        .type;
  }

  @override
  Object eval(Ctx ctx) {
    final targetValue = target.eval(ctx);
    return (targetValue as Dict<MemberID, Object>)[member].unwrap!;
  }
}

PalImpl? findImpl(Ctx ctx, PalType implementer, InterfaceType iface) {
  final maybeImpl = ctx.db.find<PalImpl>(
    ctx: ctx,
    namespace: ImplID.namespace,
    predicate: (impl) {
      if (!implementer.assignableTo(ctx, impl.implementer.read(ctx))) return false;
      return impl.implemented.read(ctx).assignableTo(ctx, iface);
    },
  );
  return maybeImpl.unwrap?.read(ctx);
}

extension PalValueGetCursorExtensions on GetCursor<Object> {
  GetCursor<Iterable<Object>> mapKeys() {
    return this.cast<Dict<Object, Object>>().keys;
  }

  GetCursor<Optional<Object>> mapAccess(Object key) {
    return this.cast<Dict<Object, Object>>()[key];
  }

  GetCursor<Object> recordAccess(MemberID member) {
    return this.cast<Dict<MemberID, Object>>()[member].whenPresent;
  }

  T dataCases<V extends Object, T>(Ctx ctx, Map<MemberID, T Function(GetCursor<V>)> cases) {
    final caseObj = this.cast<Pair<MemberID, Object>>();
    return cases[caseObj.first.read(ctx)]!(caseObj.second.cast<V>());
  }

  Object interfaceAccess(Ctx ctx, InterfaceType type, MemberID member) {
    final impl = findImpl(ctx, this.palType().read(ctx), type);
    assert(impl != null);
    return impl!.implementations[member]!.eval(ctx);
  }

  GetCursor<PalType> palType() {
    return this.cast<PalValue>().type;
  }
}

extension PalValueCursorExtensions on Cursor<Object> {
  GetCursor<Iterable<Object>> mapKeys() {
    return this.cast<Dict<Object, Object>>().keys;
  }

  Cursor<Optional<Object>> mapAccess(Object key) {
    return this.cast<Dict<Object, Object>>()[key];
  }

  Cursor<Object> recordAccess(MemberID member) {
    return this.cast<Dict<MemberID, Object>>()[member].whenPresent;
  }

  T dataCases<V extends Object, T>(Ctx ctx, Map<MemberID, T Function(Cursor<V>)> cases) {
    final caseObj = this.cast<Pair<MemberID, Object>>();
    return cases[caseObj.first.read(ctx)]!(caseObj.second.cast<V>());
  }

  Object interfaceAccess(Ctx ctx, InterfaceType type, MemberID member) {
    final impl = findImpl(ctx, this.palType().read(ctx), type);
    assert(impl != null);
    return impl!.implementations[member]!.eval(ctx.withThis(this.read(ctx) as PalValue));
  }

  Cursor<PalType> palType() {
    return this.cast<PalValue>().type;
  }

  Cursor<Object> palValue() {
    return this.cast<PalValue>().value;
  }
}

extension PalValueExtensions on Object {
  Object recordAccess(MemberID member) {
    return (this as Dict<MemberID, Object>)[member].unwrap!;
  }

  T dataCases<V extends Object, T>(Ctx ctx, Map<MemberID, T Function(V)> cases) {
    final caseObj = this as Pair<MemberID, Object>;
    return cases[caseObj.first]!(caseObj.second as V);
  }

  Object interfaceAccess<V extends Object>(
      Ctx ctx, PalType targetType, InterfaceType ifaceType, MemberID member) {
    final impl = findImpl(ctx, targetType, ifaceType);
    assert(impl != null);
    return impl!.implementations[member]!.eval(ctx);
  }
}
