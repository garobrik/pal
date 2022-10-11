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

  String string(Ctx ctx) => toString();
}

@reify
class Value extends Type with _ValueMixin {
  @override
  final Type type;
  @override
  final Object value;

  const Value(this.type, this.value);

  @override
  String toString() => 'PalValue($value: $type)';

  @override
  bool get isConcrete => type.isConcrete;
}

extension WrapValueExtension on Cursor<Object> {
  Cursor<Value> wrap(Type type) {
    return partial(
      to: (object) => Value(type, object),
      from: (diff) => DiffResult(diff.value.value, diff.diff.atPrefix(const Vec(['value']))),
      update: (old, nu, diff) => DiffResult(Value(type, nu), diff.prepend(const Vec(['value']))),
    );
  }
}

extension Assignable on Type {
  bool assignableTo(Ctx ctx, Type other) {
    return assignable(ctx, this, other);
  }
}

bool assignable(Ctx ctx, Type a, Type b) {
  if (b is TypeType || b is Unit) {
    return true;
  } else if (a is Union) {
    return a.types.every((aType) => aType.assignableTo(ctx, b));
  } else if (b is Union) {
    return b.types.any((bType) => a.assignableTo(ctx, bType));
  } else if (b is Intersection) {
    return b.types.every((bType) => a.assignableTo(ctx, bType));
  } else if (a is Intersection) {
    return a.types.any((aType) => aType.assignableTo(ctx, b));
  } else if (b is List) {
    if (a is List) {
      return (a.type as Type).assignableTo(ctx, b.type as Type);
    } else if (a is Value) {
      if (a.type is! List) return false;
      for (final value in a.value as dart.List<Type>) {
        if (!value.assignableTo(ctx, b.type as Type)) return false;
      }
      return true;
    } else {
      return false;
    }
  } else if (b is Map) {
    if (a is Map) {
      return (a.key as Type).assignableTo(ctx, b.key as Type) &&
          (a.value as Type).assignableTo(ctx, b.value as Type);
    } else if (a is Value) {
      if (a.type is! Map) return false;
      for (final entry in (a.value as dart.Map<Value, Type>).entries) {
        if (!entry.key.type.assignableTo(ctx, b.key as Type)) return false;
        if (!entry.value.assignableTo(ctx, b.value as Type)) return false;
      }
      return true;
    } else {
      return false;
    }
  } else if (b is FnType) {
    if (a is! FnType) return false;
    if (!(a.returnType as Type).assignableTo(ctx, b.returnType as Type)) {
      return false;
    }

    return (b.target as Type).assignableTo(ctx, a.target as Type);
  } else if (b is InterfaceType) {
    if (a is InterfaceType && a.id == b.id) {
      if (b.assignments.entries.every(
        (entry) => (a.assignments[entry.key] as Type).assignableTo(ctx, entry.value as Type),
      )) {
        return true;
      }
    }
    return false;
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

@reify
class List extends Type with _ListMixin {
  @override
  final Object type;

  const List(this.type);

  @override
  String toString() => 'List($type)';

  @override
  bool get isConcrete => true;
}

@reify
class Map extends Type with _MapMixin {
  @override
  final Object key;
  @override
  final Object value;

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

const type = TypeType._();

class Unit extends Type {
  const Unit._();

  @override
  String toString() => 'Unit';

  @override
  bool get isConcrete => true;
}

const unit = Unit._();

class FnType extends Type {
  final Object target;
  final Object returnType;

  const FnType({
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
  final dart.Map<MemberID, Object> assignments;

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

  InterfaceType asType([dart.Map<MemberID, Object> assignments = const {}]) =>
      InterfaceType(id: id, assignments: assignments);

  Object memberType(MemberID member) => members[member]!.type;
}

class DataType extends Type implements Traversible {
  final DataID id;
  final dart.List<MemberID> path;
  final dart.Map<MemberID, Object> assignments;

  DataType({required this.id, this.path = const [], this.assignments = const {}});

  @override
  bool get isConcrete => true;

  @override
  Object traverse(Object Function(Object) f) {
    return DataType(
      id: id,
      path: path,
      assignments: {for (final entry in assignments.entries) entry.key: doTraverse(entry.value, f)},
    );
  }

  @override
  String string(Ctx ctx) {
    return ctx.db.get(id).read(ctx).unwrap!.name;
  }
}

class DataID extends ID<DataDef> {
  static const namespace = 'PalData';

  DataID.create() : super.create(namespace: namespace);
  DataID.from(String key) : super.from(namespace, key);
}

class DataDef {
  final DataID id;
  final TypeTree tree;
  String get name => tree.name;

  DataDef.record({
    DataID? id,
    required String name,
    required dart.List<Member> members,
  })  : this.id = id ?? DataID.create(),
        tree = RecordNode(name, {
          for (final member in members) member.id: LeafNode(member.name, member.type),
        });

  DataDef.union({
    DataID? id,
    required String name,
    required dart.List<Member> members,
  })  : this.id = id ?? DataID.create(),
        tree = UnionNode(name, {
          for (final member in members) member.id: LeafNode(member.name, member.type),
        });

  DataDef({
    DataID? id,
    required this.tree,
  }) : this.id = id ?? DataID.create();

  DataDef.unit(
    String name, {
    DataID? id,
  })  : this.id = id ?? DataID.create(),
        this.tree = RecordNode(name, const {});

  DataType asType({
    dart.List<MemberID> path = const [],
    dart.Map<MemberID, Object> assignments = const {},
  }) =>
      DataType(id: id, assignments: assignments);

  Object instantiate(Object data, {Iterable<MemberID> at = const []}) =>
      tree.followPath(at).instantiate(data);

  Object followPath(Object targetObj, Iterable<MemberID> path) {
    var targetTree = this.tree;
    for (final pathElem in path) {
      if (targetTree is RecordNode) {
        targetTree = targetTree.elements[pathElem]!;
        targetObj = (targetObj as Dict<MemberID, Object>)[pathElem].unwrap!;
      } else if (targetTree is UnionNode) {
        targetTree = targetTree.elements[pathElem]!;
        final unionTag = (targetObj as UnionTag);
        assert(unionTag.tag == pathElem);
        targetObj = unionTag.value;
      } else {
        throw Exception(
          'DataType following path [${path.join(", ")}] has inconsistent path with referenced DataDef',
        );
      }
    }
    return targetObj;
  }

  String memberName(MemberID member) {
    final name = tree.memberName(member);
    assert(name != null, 'Tried to look up unknown member $member in data def $name');
    return name!;
  }

  @override
  String toString() {
    return 'DataDef(name: $name)';
  }
}

@reify
class UnionTag with _UnionTagMixin {
  @override
  @getter
  final MemberID tag;
  @override
  @skip
  final Object value;

  UnionTag(this.tag, this.value);
}

@sealed
abstract class TypeTree {
  final String name;

  const TypeTree({required this.name});

  Object traverse(Object data, Object Function(Object) f) {
    if (this is UnionNode) {
      final unionTag = data as UnionTag;
      return UnionTag(
        unionTag.tag,
        (this as UnionNode).elements[unionTag.tag]!.traverse(unionTag.value, f),
      );
    } else if (this is RecordNode) {
      final map = data as Dict<MemberID, Object>;
      final recordNode = this as RecordNode;

      return Dict({
        for (final entry in map.entries)
          entry.key: recordNode.elements[entry.key]!.traverse(entry.value, f),
      });
    } else {
      return f(data);
    }
  }

  Object instantiate(final Object data) {
    if (this is UnionNode) {
      assert(data is UnionTag && (this as UnionNode).elements.containsKey(data.tag));
      final unionTag = data as UnionTag;
      return UnionTag(
        unionTag.tag,
        (this as UnionNode).elements[unionTag.tag]!.instantiate(unionTag.value),
      );
    } else if (this is RecordNode) {
      assert(data is dart.Map<MemberID, Object>);
      final map = data as dart.Map<MemberID, Object>;
      final recordNode = this as RecordNode;
      assert(
        map.keys.every((key) => recordNode.elements.containsKey(key)) &&
            recordNode.elements.keys.every((key) => map.containsKey(key)),
      );

      return Dict({
        for (final entry in map.entries)
          entry.key: recordNode.elements[entry.key]!.instantiate(entry.value),
      });
    } else {
      return data;
    }
  }

  TypeTree followPath(Iterable<MemberID> path) {
    var targetTree = this;
    for (final pathElem in path) {
      if (targetTree is RecordNode) {
        targetTree = targetTree.elements[pathElem]!;
      } else if (targetTree is UnionNode) {
        targetTree = targetTree.elements[pathElem]!;
      } else {
        throw Exception(
          'DataType following path [${path.join(", ")}] has inconsistent path with referenced DataDef',
        );
      }
    }
    return targetTree;
  }

  String? memberName(MemberID id) {
    final tree = this;
    late final dart.Map<MemberID, TypeTree> childMap;
    if (tree is UnionNode) {
      childMap = tree.elements;
    } else if (tree is RecordNode) {
      childMap = tree.elements;
    } else {
      childMap = const {};
    }

    for (final entry in childMap.entries) {
      if (entry.key == id) return entry.value.name;
      final childName = entry.value.memberName(id);
      if (childName != null) return childName;
    }

    return null;
  }
}

class UnionNode extends TypeTree {
  final dart.Map<MemberID, TypeTree> elements;

  const UnionNode(String name, this.elements) : super(name: name);
}

class RecordNode extends TypeTree {
  final dart.Map<MemberID, TypeTree> elements;

  const RecordNode(String name, this.elements) : super(name: name);
}

class LeafNode extends TypeTree {
  final Object type;

  const LeafNode(String name, this.type) : super(name: name);
}

class Member {
  final MemberID id;
  final String name;
  final Object type;

  Member({MemberID? id, required this.name, required this.type}) : id = id ?? MemberID();
}

@reify
class Impl with _ImplMixin {
  @override
  final ImplID id;
  @override
  final InterfaceType implemented;
  @override
  final Dict<MemberID, Expr> implementations;

  Impl({
    ImplID? id,
    required this.implemented,
    required this.implementations,
  }) : this.id = id ?? ImplID.create();
}

Cursor<Impl>? findImpl(Ctx ctx, InterfaceType iface) {
  return ctx.db
      .find<Impl>(
        ctx: ctx,
        namespace: ImplID.namespace,
        predicate: (impl) => iface.assignableTo(ctx, impl.implemented.read(ctx)),
      )
      .unwrap;
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

  GetCursor<MemberID> get dataCase => this.cast<UnionTag>().tag;

  T dataCases<T>(Ctx ctx, dart.Map<MemberID, T Function(GetCursor<Object>)> cases) {
    final unionTag = this.cast<UnionTag>();
    final currentTag = unionTag.tag.read(ctx);
    return cases[currentTag]!(unionTag.thenOpt(
      OptLens(
        const Vec(['value']),
        (t) => t.tag == currentTag ? Optional(t.value) : const Optional.none(),
        (t, f) => UnionTag(t.tag, f(t.value)),
      ),
    ));
  }

  Object interfaceAccess(Ctx ctx, MemberID member) => this.read(ctx).interfaceAccess(ctx, member);

  GetCursor<Type> palType() => this.cast<Value>().type;

  GetCursor<Object> palValue() => this.cast<Value>().value;

  Object callFn(Ctx ctx, Object arg) => this.read(ctx).callFn(ctx, arg);
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

  T dataCases<T>(Ctx ctx, dart.Map<MemberID, T Function(Cursor<Object>)> cases) {
    final unionTag = this.cast<UnionTag>();
    final currentTag = unionTag.tag.read(ctx);
    return cases[currentTag]!(unionTag.thenOpt(
      OptLens(
        const Vec(['value']),
        (t) => t.tag == currentTag ? Optional(t.value) : const Optional.none(),
        (t, f) => UnionTag(t.tag, f(t.value)),
      ),
    ));
  }

  Object interfaceAccess(Ctx ctx, MemberID member) => this.read(ctx).interfaceAccess(ctx, member);

  Cursor<Type> palType() => this.cast<Value>().type;

  Cursor<Object> palValue() => this.cast<Value>().value;
}

typedef DartFnType = Object Function(Ctx ctx, Object arg);

extension PalValueExtensions on Object {
  Optional<Object> mapAccess(Object key) {
    return (this as Dict<Object, Object>)[key];
  }

  Object recordAccess(MemberID member) {
    return (this as Dict<MemberID, Object>)[member].unwrap!;
  }

  T dataCases<V extends Object, T>(Ctx ctx, dart.Map<MemberID, T Function(V)> cases) {
    final caseObj = this as Pair<MemberID, Object>;
    return cases[caseObj.first]!(caseObj.second as V);
  }

  Object interfaceAccess(Ctx ctx, MemberID member) {
    return (this as Impl).implementations[member].unwrap!.eval(ctx.withThisImpl(this as Impl));
  }

  Object callFn(Ctx ctx, Object arg) {
    if (this is Function) {
      return (this as Object Function(Ctx, Object))(ctx, arg);
    } else if (this is FnExpr) {
      final fnExpr = this as FnExpr;
      return fnExpr.body.eval(ctx.withFnArg(fnExpr.type, arg));
    } else {
      throw Exception('Tried to call unexpected type ${this.runtimeType} as pal function.');
    }
  }
}
