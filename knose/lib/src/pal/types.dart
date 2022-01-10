import 'dart:core' as dart;
import 'dart:core';
import 'package:knose/uuid.dart';
import 'package:meta/meta.dart';

import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/pal.dart';

part 'types.g.dart';

class ImplID extends ID<Impl> {
  static const namespace = 'PalImpl';

  ImplID.create() : super.create(namespace: namespace);
  ImplID.from(String key) : super.from(namespace, key);
}

abstract class Type {
  const Type();

  bool get isConcrete;
}

@reify
class Value extends Type with _ValueMixin implements Expr {
  @override
  final Type type;
  @override
  final Object value;

  const Value(this.type, this.value);

  @override
  Type evalType(Ctx ctx) => type;

  @override
  Object eval(Ctx ctx) {
    if (type == typeType) {
      if (value is DataType) {
        return DataType(
          id: (value as DataType).id,
          assignments: (value as DataType).assignments.map(
                (key, value) => MapEntry(
                  key,
                  value is Expr ? value.eval(ctx) as Type : value,
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

extension WrapValueExtension on Cursor<Object> {
  Cursor<Value> wrap(Type type) {
    return partial(
      to: (object) => Value(type, object),
      from: (diff) => DiffResult(diff.value.value, diff.diff.atPrefix(['value'])),
      update: (old, nu, diff) => DiffResult(Value(type, nu), diff.prepend(['value'])),
    );
  }
}

extension Assignable on Type {
  bool assignableTo(Ctx ctx, Type other) {
    return assignable(ctx, this, other);
  }
}

bool assignable(Ctx ctx, Type a, Type b) {
  if (b is Any || b is TypeType || b is Unit) {
    return true;
  } else if (a is Union) {
    return a.types.every((aType) => aType.assignableTo(ctx, b));
  } else if (b is Union) {
    return b.types.any((bType) => a.assignableTo(ctx, bType));
  } else if (b is Intersection) {
    return b.types.every((bType) => a.assignableTo(ctx, bType));
  } else if (a is Intersection) {
    return a.types.any((aType) => aType.assignableTo(ctx, b));
  } else if (a is Expr) {
    return (a.eval(ctx) as Type).assignableTo(ctx, b);
  } else if (b is Expr) {
    return a.assignableTo(ctx, b.eval(ctx) as Type);
  } else if (b is List) {
    if (a is List) {
      return a.type.assignableTo(ctx, b.type);
    } else if (a is Value) {
      if (a.type is! List) return false;
      for (final value in a.value as dart.List<Type>) {
        if (!value.assignableTo(ctx, b.type)) return false;
      }
      return true;
    } else {
      return false;
    }
  } else if (b is Map) {
    if (a is Map) {
      return a.key.assignableTo(ctx, b.key) && a.value.assignableTo(ctx, b.value);
    } else if (a is Value) {
      if (a.type is! Map) return false;
      for (final entry in (a.value as dart.Map<Value, Type>).entries) {
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

    final implementation = ctx.db.find<Impl>(
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
  } else if (b is Value) {
    if (a is! Value) return false;
    if (!a.type.assignableTo(ctx, b.type)) return false;
    if (b.type is Map) {
      if (a.type is! Map) return false;
      final aMap = a.value as dart.Map<Value, Type>;
      final bMap = b.value as dart.Map<Value, Type>;
      if (aMap.length != bMap.length) return false;
      for (final entry in aMap.entries) {
        final bValue = bMap[entry.key];
        if (bValue == null) return false;
        if (!entry.value.assignableTo(ctx, bValue)) return false;
      }
      return true;
    } else if (b.type is List) {
      if (a.type is! List) return false;
      final aList = a.value as dart.List<Type>;
      final bList = b.value as dart.List<Type>;
      if (aList.length != bList.length) return false;
      for (final pair in zip(aList, bList)) {
        if (!pair.first.assignableTo(ctx, pair.second)) return false;
      }
      return true;
    } else {
      return a.value == b.value;
    }
  } else if (a is Value) {
    return a.type.assignableTo(ctx, b);
  } else {
    return a == b;
  }
}

class Any extends Type {
  const Any._();
  @override
  String toString() => 'Any';

  @override
  bool get isConcrete => false;
}

const any = Any._();

class ThisType extends Type {
  const ThisType._();

  @override
  String toString() => 'This';

  @override
  bool get isConcrete => false;
}

const thisType = ThisType._();

@reify
class List extends Type with _ListMixin {
  @override
  final Type type;

  const List(this.type);

  @override
  String toString() => 'List($type)';

  @override
  bool get isConcrete => true;
}

@reify
class Map extends Type with _MapMixin {
  @override
  final Type key;
  @override
  final Type value;

  const Map(this.key, this.value);

  @override
  String toString() => 'Map($key, $value)';

  @override
  bool get isConcrete => true;
}

class Union extends Type {
  final dart.Set<Type> types;

  const Union(this.types) : assert(types.length > 1);

  @override
  String toString() => 'Union(${types.join(", ")})';

  @override
  bool get isConcrete => false;
}

class Intersection extends Type {
  final dart.Set<Type> types;

  const Intersection(this.types) : assert(types.length > 1);

  @override
  String toString() => 'Intersection(${types.join(", ")})';

  @override
  bool get isConcrete => false;
}

class Boolean extends Type {
  const Boolean._();

  @override
  String toString() => 'Boolean';

  @override
  bool get isConcrete => true;
}

const boolean = Boolean._();

class Number extends Type {
  const Number._();

  @override
  String toString() => 'Number';

  @override
  bool get isConcrete => true;
}

const number = Number._();

class Text extends Type {
  const Text._();

  @override
  String toString() => 'Text';

  @override
  bool get isConcrete => true;
}

const text = Text._();

class TypeType extends Type {
  const TypeType._();

  @override
  String toString() => 'Type';

  @override
  bool get isConcrete => true;
}

const typeType = TypeType._();

class Unit extends Type {
  const Unit._();

  @override
  String toString() => 'Unit';

  @override
  bool get isConcrete => true;
}

const unit = Unit._();

class FunctionType extends Type {
  final Type target;
  final Type returnType;

  const FunctionType({
    this.target = unit,
    this.returnType = unit,
  });

  @override
  String toString() => '($target) => $returnType';

  @override
  bool get isConcrete => true;
}

class MemberID extends UUID<MemberID> {}

class InterfaceType extends Type {
  final InterfaceID id;
  final dart.Map<MemberID, Type> assignments;

  InterfaceType({required this.id, this.assignments = const {}});

  @override
  String toString() => 'Interface($id)';

  @override
  bool get isConcrete => false;
}

class InterfaceID extends ID<InterfaceDef> {
  static const namespace = 'PalInterface';

  InterfaceID.create() : super.create(namespace: namespace);
  InterfaceID.from(String key) : super.from(namespace, key);
}

class InterfaceDef {
  final InterfaceID id;
  final String name;
  final dart.Map<MemberID, Member> members;

  InterfaceDef({
    InterfaceID? id,
    required this.name,
    required dart.List<Member> members,
  })  : this.id = id ?? InterfaceID.create(),
        members = {for (final member in members) member.id: member};

  InterfaceType asType([dart.Map<MemberID, Type> assignments = const {}]) =>
      InterfaceType(id: id, assignments: assignments);
}

class DataType extends Type {
  final DataID id;
  final dart.Map<MemberID, Type> assignments;

  DataType({required this.id, this.assignments = const {}});

  @override
  bool get isConcrete => true;
}

class DataID extends ID<DataDef> {
  static const namespace = 'PalData';

  DataID.create() : super.create(namespace: namespace);
  DataID.from(String key) : super.from(namespace, key);
}

class DataDef {
  final DataID id;
  final String name;
  final DataTree<Type> tree;

  DataDef.record({
    DataID? id,
    required this.name,
    required dart.List<Member> members,
  })  : this.id = id ?? DataID.create(),
        tree = RecordNode({
          for (final member in members)
            member.id: DataTreeElement(member.name, LeafNode(member.type)),
        });

  DataDef.union({
    DataID? id,
    required this.name,
    required dart.List<Member> members,
  })  : this.id = id ?? DataID.create(),
        tree = UnionNode({
          for (final member in members)
            member.id: DataTreeElement(member.name, LeafNode(member.type)),
        });

  DataDef({
    DataID? id,
    required this.name,
    this.tree = const RecordNode({}),
  }) : this.id = id ?? DataID.create();

  DataType asType([dart.Map<MemberID, Type> assignments = const {}]) =>
      DataType(id: id, assignments: assignments);
}

@sealed
abstract class DataTree<T> {
  const DataTree();
}

class UnionNode<T> extends DataTree<T> {
  final dart.Map<MemberID, DataTreeElement<T>> elements;

  const UnionNode(this.elements);
}

class RecordNode<T> extends DataTree<T> {
  final dart.Map<MemberID, DataTreeElement<T>> elements;

  const RecordNode(this.elements);
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

class Member {
  final MemberID id;
  final String name;
  final Type type;

  Member({MemberID? id, required this.name, required this.type}) : id = id ?? MemberID();
}

@reify
class Impl with _ImplMixin {
  @override
  final ImplID id;
  @override
  final Type implementer;
  @override
  final InterfaceType implemented;
  @override
  final dart.Map<MemberID, Expr> implementations;

  Impl({
    ImplID? id,
    required this.implementer,
    required this.implemented,
    required this.implementations,
  }) : this.id = id ?? ImplID.create();
}

abstract class Expr extends Type {
  const Expr();

  Type evalType(Ctx ctx);
  Object eval(Ctx ctx);

  @override
  bool get isConcrete => false;
}

class ThisExpr extends Expr {
  const ThisExpr._();

  @override
  Type evalType(Ctx ctx) => ctx.thisValue.type;

  @override
  Object eval(Ctx ctx) => ctx.thisValue.value;
}

const thisExpr = ThisExpr._();

extension _ThisCtxExtension on Ctx {
  Value get thisValue => get<_ThisCtx>()!.thisCtx;
  Ctx withThis(Value value) => withElement(_ThisCtx(value));
}

class _ThisCtx extends CtxElement {
  final Value thisCtx;

  const _ThisCtx(this.thisCtx);
}

class InterfaceAccess extends Expr {
  final Expr target;
  final InterfaceType iface;
  final MemberID member;

  InterfaceAccess({
    required this.member,
    this.target = thisExpr,
    required this.iface,
  });

  @override
  Type evalType(Ctx ctx) {
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
    return impl!.implementations[member]!.eval(ctx.withThis(Value(targetType, targetValue)));
  }
}

class RecordAccess extends Expr {
  final Expr target;
  final MemberID member;

  RecordAccess(this.member, {this.target = thisExpr});

  @override
  Type evalType(Ctx ctx) {
    final targetType = target.evalType(ctx) as DataType;
    if (targetType.assignments.containsKey(member)) {
      return targetType.assignments[member]!;
    }
    return ((ctx.db.get(targetType.id).whenPresent.read(ctx).tree as RecordNode<Type>)
            .elements[member]!
            .node as LeafNode<Type>)
        .type;
  }

  @override
  Object eval(Ctx ctx) {
    final targetValue = target.eval(ctx);
    return (targetValue as Dict<MemberID, Object>)[member].unwrap!;
  }
}

Impl? findImpl(Ctx ctx, Type implementer, InterfaceType iface) {
  final maybeImpl = ctx.db.find<Impl>(
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

  T dataCases<V extends Object, T>(Ctx ctx, dart.Map<MemberID, T Function(GetCursor<V>)> cases) {
    final caseObj = this.cast<Pair<MemberID, Object>>();
    return cases[caseObj.first.read(ctx)]!(caseObj.second.cast<V>());
  }

  Object interfaceAccess(Ctx ctx, InterfaceType type, MemberID member) {
    final impl = findImpl(ctx, this.palType().read(ctx), type);
    assert(impl != null);
    return impl!.implementations[member]!.eval(ctx);
  }

  GetCursor<Type> palType() {
    return this.cast<Value>().type;
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

  T dataCases<V extends Object, T>(Ctx ctx, dart.Map<MemberID, T Function(Cursor<V>)> cases) {
    final caseObj = this.cast<Pair<MemberID, Object>>();
    return cases[caseObj.first.read(ctx)]!(caseObj.second.cast<V>());
  }

  Object interfaceAccess(Ctx ctx, InterfaceType type, MemberID member) {
    final impl = findImpl(ctx, this.palType().read(ctx), type);
    assert(impl != null);
    return impl!.implementations[member]!.eval(ctx.withThis(this.read(ctx) as Value));
  }

  Cursor<Type> palType() {
    return this.cast<Value>().type;
  }

  Cursor<Object> palValue() {
    return this.cast<Value>().value;
  }
}

extension PalValueExtensions on Object {
  Object recordAccess(MemberID member) {
    return (this as Dict<MemberID, Object>)[member].unwrap!;
  }

  T dataCases<V extends Object, T>(Ctx ctx, dart.Map<MemberID, T Function(V)> cases) {
    final caseObj = this as Pair<MemberID, Object>;
    return cases[caseObj.first]!(caseObj.second as V);
  }

  Object interfaceAccess<V extends Object>(Ctx ctx, InterfaceType ifaceType, MemberID member) {
    final impl = findImpl(ctx, (this as Value).type, ifaceType);
    assert(impl != null);
    return impl!.implementations[member]!.eval(ctx.withThis(this as Value));
  }
}
