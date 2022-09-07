import 'dart:core' as dart;
import 'dart:core';
import 'package:ctx/ctx.dart';
import 'package:reified_lenses/reified_lenses.dart' as reified;
import 'package:uuid/uuid.dart';

typedef Dict = reified.Dict<Object, Object>;
typedef Vec = reified.Vec<Object>;

class ID extends Comparable<ID> {
  static final def = TypeDef.unit('ID');
  static final type = TypeDef.asType(def);

  static const _uuid = Uuid();

  final String id;
  final ID? tail;
  final String? label;

  ID([this.label])
      : id = _uuid.v4(),
        tail = null;

  ID.from({
    required this.id,
    required this.label,
    required this.tail,
  });

  @override
  bool operator ==(Object other) => other is ID && id == other.id && tail == other.tail;

  @override
  int get hashCode => Object.hash(id.hashCode, tail);

  @override
  String toString() => '$runtimeType(${_toStringImpl()})';
  String _toStringImpl() => (label ?? id) + (tail == null ? '' : '.${tail!._toStringImpl()}');

  @override
  int compareTo(ID other) {
    final compareID = id.compareTo(other.id);
    if (compareID != 0) return compareID;
    if (tail == null && other.tail == null) return 0;
    if (tail == null) return -1;
    if (other.tail == null) return 1;
    return tail!.compareTo(other.tail!);
  }

  dynamic toJson() => id;

  ID append(ID other) =>
      ID.from(id: id, label: label, tail: tail == null ? other : tail!.append(other));
}

abstract class Module {
  static final IDID = ID('ID');
  static final nameID = ID('name');
  static final definitionsID = ID('definitions');

  static final def = TypeDef.record('Module', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    nameID: TypeTree.mk('name', Literal.mk(Type.type, text)),
    definitionsID: TypeTree.mk('definitions', Literal.mk(Type.type, List.type(ModuleDef.type))),
  });
  static final type = TypeDef.asType(def);

  static Object mk({ID? id, required String name, required Vec definitions}) =>
      Dict({IDID: id ?? ID(), nameID: name, definitionsID: definitions});

  static Ctx load(Ctx evalCtx, Ctx targetCtx, Object module) {
    Iterable<Object> expandDef(Object moduleDef) {
      final list = eval(
        evalCtx,
        FnApp.mk(
          InterfaceAccess.mk(
            target: RecordAccess.mk(
              target: Literal.mk(ModuleDef.type, moduleDef),
              member: ModuleDef.implID,
            ),
            member: ModuleDef.bindingsID,
          ),
          RecordAccess.mk(target: Literal.mk(ModuleDef.type, moduleDef), member: ModuleDef.dataID),
        ),
      ) as Vec;
      return list.expand(
        (union) => Union.cases(union, {
          ModuleDef.type: expandDef,
          Binding.type: (binding) => [binding],
        }),
      );
    }

    final bindings = ((module as Dict)[definitionsID].unwrap! as Vec).expand(expandDef);
    return bindings.fold(targetCtx, (ctx, binding) => ctx.withBinding(binding));
  }

  static final bindingOrDef = Union.type(Vec([ModuleDef.type, Binding.type]));
}

abstract class ModuleDef extends InterfaceDef {
  static final dataTypeID = ID('dataType');
  static final typeCheckID = ID('bindingTypes');
  static final bindingsID = ID('bindings');
  static final interfaceDef = InterfaceDef.record('ModuleDef', {
    dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    typeCheckID: TypeTree.mk(
      'bindingTypes',
      Fn.typeExpr(
        argType: RecordAccess.mk(target: thisDef, member: dataTypeID),
        returnType: Literal.mk(Type.type, List.type(Module.bindingOrDef)),
      ),
    ),
    bindingsID: TypeTree.mk(
      'bindings',
      Fn.typeExpr(
        argType: RecordAccess.mk(target: thisDef, member: dataTypeID),
        returnType: Literal.mk(Type.type, List.type(Module.bindingOrDef)),
      ),
    ),
  });

  static Object mkImpl({
    required Object dataType,
    required Object typeCheck,
    required Object bindings,
    ID? id,
  }) =>
      ImplDef.mk(
        implemented: InterfaceDef.id(interfaceDef),
        members: Dict({
          dataTypeID: Literal.mk(Type.type, dataType),
          typeCheckID: typeCheck,
          bindingsID: bindings,
        }),
      );

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final typeDefID = ID('ModuleDef');
  static final typeDef = TypeDef.record(
    'ModuleDef',
    {
      implID: TypeTree.mk('impl', Literal.mk(Type.type, Impl.type(InterfaceDef.id(interfaceDef)))),
      dataID: TypeTree.mk(
        'data',
        InterfaceAccess.mk(
          target: RecordAccess.mk(target: thisDef, member: implID),
          member: dataTypeID,
        ),
      ),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static Object mk({required Object impl, required Object data}) =>
      Dict({implID: impl, dataID: data});

  static Object mkExpr({required Object impl, required Object data}) =>
      Construct.mk(ModuleDef.type, Dict({implID: impl, dataID: data}));
}

abstract class ValueDef {
  static final IDID = ID('ID');
  static final nameID = ID('name');
  static final valueID = ID('value');

  static final typeDef = TypeDef.record('ValueDef', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    nameID: TypeTree.mk('name', Literal.mk(Type.type, text)),
    valueID: TypeTree.mk('value', Literal.mk(Type.type, Expr.type)),
  });

  static Object mk({required ID id, required String name, required Object value}) => ModuleDef.mk(
      impl: ImplDef.asImpl(moduleDefImplDef), data: Dict({IDID: id, nameID: name, valueID: value}));

  static Object mkExpr({required ID id, required String name, required Object value}) =>
      ModuleDef.mkExpr(
        impl: Literal.mk(
            Impl.type(InterfaceDef.id(ModuleDef.interfaceDef)), ImplDef.asImpl(moduleDefImplDef)),
        data: Construct.mk(
          TypeDef.asType(typeDef),
          Dict(
            {IDID: id, nameID: name, valueID: value},
          ),
        ),
      );

  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: TypeDef.asType(typeDef),
    typeCheck: Fn.dart(
      argName: 'valueDef',
      type: Fn.type(argType: TypeDef.asType(typeDef), returnType: List.type(Binding.type)),
      body: (ctx, arg) => Option.cases(
        typeCheck(ctx, (arg as Dict)[valueID].unwrap!),
        some: (type) => Vec([
          Union.mk(
            Vec([ModuleDef.type, Binding.type]),
            Binding.type,
            Binding.mk(
              id: arg[IDID].unwrap! as ID,
              name: arg[nameID].unwrap! as String,
              type: type,
            ),
          )
        ]),
        none: () => Option.mk(List.type(Binding.type)),
      ),
    ),
    bindings: Fn.dart(
      argName: 'valueDef',
      type: Fn.type(argType: TypeDef.asType(typeDef), returnType: List.type(Binding.type)),
      body: (ctx, arg) => Option.cases(
        typeCheck(ctx, (arg as Dict)[valueID].unwrap!),
        some: (type) => Vec([
          Union.mk(
            Vec([ModuleDef.type, Binding.type]),
            Binding.type,
            Binding.mk(
              id: arg[IDID].unwrap! as ID,
              name: arg[nameID].unwrap! as String,
              type: type,
              value: eval(ctx, arg[valueID].unwrap!),
            ),
          ),
        ]),
        none: () => Option.mk(List.type(Binding.type)),
      ),
    ),
  );
}

abstract class TypeDef {
  static final IDID = ID('ID');
  static final treeID = ID('tree');

  static Object record(String name, dart.Map<ID, Object> members, {ID? id}) =>
      mk(TypeTree.record(name, members), id: id);
  static Object union(String name, dart.Map<ID, Dict> cases, {ID? id}) =>
      mk(TypeTree.union(name, cases), id: id);
  static Object unit(String name, {ID? id}) => mk(TypeTree.unit(name), id: id);

  static Object mk(Object tree, {ID? id}) =>
      Dict({IDID: id ?? ID(TypeTree.name(tree)), treeID: tree});

  static Object asType(Object typeDef, {Vec properties = const Vec()}) => Type.mk(
        (typeDef as Dict)[IDID].unwrap! as ID,
        properties: properties,
      );

  static ID id(Object typeDef) => (typeDef as Dict)[IDID].unwrap! as ID;
  static Object tree(Object typeDef) => (typeDef as Dict)[treeID].unwrap!;

  static final def = TypeDef.record('TypeDef', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    treeID: TypeTree.mk('tree', Literal.mk(Type.type, TypeTree.type)),
  });
  static final type = asType(def);

  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: type,
    typeCheck: Fn.dart(
      argName: 'typeDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (ctx, typeDef) {
        return Vec([
          Union.mk(
            Vec([ModuleDef.type, Binding.type]),
            Binding.type,
            Binding.mk(
              id: TypeDef.id(typeDef),
              type: Literal.mk(Type.type, TypeDef.type),
              name: TypeTree.name(TypeDef.tree(typeDef)),
            ),
          ),
          Union.mk(
            Vec([ModuleDef.type, Binding.type]),
            ModuleDef.type,
            ValueDef.mk(
              id: ID(),
              name: TypeTree.name(TypeDef.tree(typeDef)),
              value: Literal.mk(Type.type, TypeDef.asType(typeDef)),
            ),
          ),
        ]);
      },
    ),
    bindings: Fn.dart(
      argName: 'typeDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (ctx, typeDef) {
        return Vec([
          Union.mk(
            Vec([ModuleDef.type, Binding.type]),
            Binding.type,
            Binding.mk(
              id: TypeDef.id(typeDef),
              type: TypeDef.type,
              name: TypeTree.name(TypeDef.tree(typeDef)),
              value: typeDef,
            ),
          ),
          Union.mk(
            Vec([ModuleDef.type, Binding.type]),
            ModuleDef.type,
            ValueDef.mk(
              id: ID(),
              name: TypeTree.name(TypeDef.tree(typeDef)),
              value: Literal.mk(Type.type, TypeDef.asType(typeDef)),
            ),
          ),
        ]);
      },
    ),
  );
  static final moduleDefImpl = ImplDef.asImpl(moduleDefImplDef);

  static Object mkDef(Object def) => ModuleDef.mk(impl: moduleDefImpl, data: def);
}

abstract class Type {
  static final IDID = ID('ID');
  static final pathID = ID('path');
  static final propertiesID = ID('properties');

  static final _typeID = ID('Type');
  static final def = TypeDef.record(
    'Type',
    {
      IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
      pathID: TypeTree.mk('path', Literal.mk(Type.type, List.type(ID.type))),
      propertiesID: TypeTree.mk('properties', Literal.mk(Type.type, List.type(TypeProperty.type))),
    },
    id: _typeID,
  );
  static final type = Type.mk(_typeID);

  static Dict mk(
    ID id, {
    Vec path = const Vec(),
    Vec properties = const Vec(),
  }) =>
      Dict({IDID: id, pathID: path, propertiesID: properties});

  static Object mkExpr(
    ID id, {
    Object? path,
    Object? properties,
  }) =>
      Construct.mk(
        Type.type,
        Dict({
          IDID: Literal.mk(ID.type, id),
          pathID: path ?? Literal.mk(List.type(ID.type), const Vec()),
          propertiesID: properties ?? Literal.mk(List.type(TypeProperty.type), const Vec()),
        }),
      );

  static ID id(Object type) => (type as Dict)[IDID].unwrap! as ID;
  static Vec path(Object type) => (type as Dict)[pathID].unwrap! as Vec;
  static Vec properties(Object type) => (type as Dict)[propertiesID].unwrap! as Vec;
  static Object memberEquals(Object type, dart.List<ID> path) {
    return properties(type).expand<Object>((property) {
      if (TypeProperty.impl(property) != MemberHas.impl) return [];
      final memberHas = TypeProperty.data(property);
      if (MemberHas.path(memberHas) != Vec(path)) return [];
      final memberHasProp = MemberHas.property(memberHas);
      if (TypeProperty.impl(memberHasProp) != Equals.impl) return [];
      return [Equals.equalTo(TypeProperty.data(memberHasProp))];
    }).first;
  }
}

abstract class TypeProperty {
  static final dataTypeID = ID('dataType');
  static final hasID = ID('has');
  static final interfaceID = ID('interface');
  static final interfaceDef = InterfaceDef.record(
    'TypePropertyImpl',
    {
      dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
      // hasID: TypeTree.mk(
      //   'has',
      //   Fn.typeExpr(
      //     argType: InterfaceAccess.mk(target: thisDef, member: dataTypeID),
      //     returnType: Literal.mk(Type.type, boolean),
      //   ),
      // ),
    },
    id: interfaceID,
  );

  static Dict mkImpl({
    ID? id,
    required Object dataType,
    required Object has,
  }) =>
      ImplDef.mk(
        id: id,
        implemented: interfaceID,
        members: Dict({dataTypeID: Literal.mk(Type.type, dataType), hasID: has}),
      );

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final typeDef = TypeDef.record('TypeProperty', {
    implID: TypeTree.mk('impl', Literal.mk(Type.type, Impl.type(interfaceID))),
    dataID: TypeTree.mk(
      'data',
      InterfaceAccess.mk(
          target: RecordAccess.mk(target: thisDef, member: implID), member: dataTypeID),
    ),
  });
  static final type = TypeDef.asType(typeDef);

  static Dict mk(Object impl, Object data) => Dict({implID: impl, dataID: data});

  static Object mkExpr(Object impl, Object data) =>
      Construct.mk(type, Dict({implID: impl, dataID: data}));

  static Object impl(Object typeProperty) => (typeProperty as Dict)[implID].unwrap!;
  static Object data(Object typeProperty) => (typeProperty as Dict)[dataID].unwrap!;
}

abstract class Equals extends TypeProperty {
  static final dataTypeID = ID('dataType');
  static final equalToID = ID('equalTo');

  static final typeDef = TypeDef.record('Equals', {
    dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    equalToID: TypeTree.mk('equalTo', RecordAccess.mk(target: thisDef, member: dataTypeID)),
  });

  static final implID = ID('impl');
  static final propImplDef = TypeProperty.mkImpl(
    id: implID,
    dataType: TypeDef.asType(typeDef),
    has: Fn.from(
      argName: 'equalsData',
      type: Fn.type(argType: TypeDef.asType(typeDef), returnType: boolean),
      body: (_) => Literal.mk(boolean, true),
    ),
  );
  static final impl = Impl.mk(implID);

  static Dict mk(Object dataType, Object equalTo) =>
      TypeProperty.mk(impl, Dict({dataTypeID: dataType, equalToID: equalTo}));

  static Object mkExpr(Object dataType, Object equalTo) => TypeProperty.mkExpr(
        Literal.mk(Impl.type(implID), impl),
        Construct.mk(TypeDef.asType(typeDef), Dict({dataTypeID: dataType, equalToID: equalTo})),
      );

  static Object equalTo(Object memberIs) => (memberIs as Dict)[equalToID].unwrap!;
}

abstract class ImplHas extends TypeProperty {
  static final propertyID = ID('property');

  static final typeDef = TypeDef.record('ImplHas', {
    propertyID: TypeTree.mk('property', Literal.mk(Type.type, TypeProperty.type)),
  });

  static final implID = ID('impl');
  static final propImplDef = TypeProperty.mkImpl(
    id: implID,
    dataType: TypeDef.asType(typeDef),
    has: Fn.from(
      argName: 'implHasData',
      type: Fn.type(argType: TypeDef.asType(typeDef), returnType: boolean),
      body: (_) => Literal.mk(boolean, true),
    ),
  );
  static final impl = Impl.mk(implID);

  static Object mk({required Object property}) =>
      TypeProperty.mk(impl, Dict({propertyID: property}));

  static Object mkExpr({required Object property}) => TypeProperty.mkExpr(
        Literal.mk(Impl.type(implID), impl),
        Construct.mk(TypeDef.asType(typeDef), Dict({propertyID: property})),
      );

  static Object property(Object memberIs) => (memberIs as Dict)[propertyID].unwrap!;
}

abstract class MemberHas extends TypeProperty {
  static final pathID = ID('path');
  static final propertyID = ID('property');

  static final typeDef = TypeDef.record('MemberHas', {
    pathID: TypeTree.mk('path', Literal.mk(Type.type, List.type(ID.type))),
    propertyID: TypeTree.mk('property', Literal.mk(Type.type, TypeProperty.type)),
  });

  static final implID = ID('impl');
  static final propImplDef = TypeProperty.mkImpl(
    id: implID,
    dataType: TypeDef.asType(typeDef),
    has: Fn.from(
      argName: 'memberHasData',
      type: Fn.type(argType: TypeDef.asType(typeDef), returnType: boolean),
      body: (_) => Literal.mk(boolean, true),
    ),
  );
  static final impl = Impl.mk(implID);

  static Object mk({required Object path, required Object property}) =>
      TypeProperty.mk(impl, Dict({pathID: path, propertyID: property}));

  static Object mkExpr({required Object path, required Object property}) => TypeProperty.mkExpr(
        Literal.mk(Impl.type(implID), impl),
        Construct.mk(TypeDef.asType(typeDef), Dict({pathID: path, propertyID: property})),
      );

  static Vec path(Object memberHas) => (memberHas as Dict)[pathID].unwrap! as Vec;
  static Object property(Object memberHas) => (memberHas as Dict)[propertyID].unwrap!;
}

abstract class UnionTag {
  static final tagID = ID('tag');
  static final valueID = ID('value');

  static final def = TypeDef.record('UnionTag', {
    tagID: TypeTree.mk('tag', Literal.mk(Type.type, ID.type)),
    valueID: TypeTree.mk('value', Literal.mk(Type.type, Any.type)),
  });

  static final type = TypeDef.asType(def);

  static Dict mk(ID tag, Object value) => Dict({tagID: tag, valueID: value});

  static ID tag(Object unionTag) => (unionTag as Dict)[tagID].unwrap! as ID;
  static Object value(Object unionTag) => (unionTag as Dict)[valueID].unwrap!;
}

abstract class TypeTree {
  static final nameID = ID('name');
  static final treeID = ID('tree');
  static final recordID = ID('record');
  static final unionID = ID('union');
  static final leafID = ID('leaf');

  static final id = ID('TypeTree');
  static final def = TypeDef.record(
    'TypeTree',
    {
      nameID: TypeTree.mk('name', Literal.mk(Type.type, text)),
      treeID: TypeTree.union('tree', {
        recordID: TypeTree.mk('record', Literal.mk(Type.type, Map.type(ID.type, TypeTree.type))),
        unionID: TypeTree.mk('union', Literal.mk(Type.type, Map.type(ID.type, TypeTree.type))),
        leafID: TypeTree.mk('leaf', Literal.mk(Type.type, Expr.type))
      }),
    },
    id: id,
  );
  static final type = Type.mk(id);

  static Dict record(String name, dart.Map<ID, Object> members) =>
      Dict({nameID: name, treeID: UnionTag.mk(recordID, Dict(members))});
  static Dict union(String name, dart.Map<ID, Dict> cases) =>
      Dict({nameID: name, treeID: UnionTag.mk(unionID, Dict(cases))});
  static Dict mk(String name, Object type) =>
      Dict({nameID: name, treeID: UnionTag.mk(leafID, type)});
  static Dict unit(String name) => TypeTree.record(name, const {});

  static String name(Object typeTree) => (typeTree as Dict)[nameID].unwrap! as String;
  static Object tree(Object typeTree) => (typeTree as Dict)[treeID].unwrap!;

  static T treeCases<T>(
    Object typeTree, {
    required T Function(Dict) record,
    required T Function(Dict) union,
    required T Function(Dict) leaf,
  }) {
    final tree = TypeTree.tree(typeTree);
    final tag = UnionTag.tag(tree);
    final value = UnionTag.value(tree);
    if (tag == recordID) {
      return record(value as Dict);
    } else if (tag == unionID) {
      return union(value as Dict);
    } else if (tag == leafID) {
      return leaf(value as Dict);
    } else {
      throw Exception("unknown tree case");
    }
  }

  static Object treeAt(Object typeTree, Vec path) {
    if (path.isEmpty) {
      return typeTree;
    } else {
      return treeCases(
        typeTree,
        record: (record) => treeAt(record[path.first].unwrap!, path.tail),
        union: (union) => treeAt(union[path.first].unwrap!, path.tail),
        leaf: (leaf) => throw Exception('tried to look up type tree at unknown location'),
      );
    }
  }

  static Object dataAt(Object typeTree, Object data, Vec path) {
    if (path.isEmpty) {
      return data;
    } else {
      return treeCases(
        typeTree,
        record: (record) => dataAt(
          record[path.first].unwrap!,
          (data as Dict)[path.first].unwrap!,
          path.tail,
        ),
        union: (union) {
          assert(UnionTag.tag(data) == path.first);
          return dataAt(
            union[path.first].unwrap!,
            UnionTag.value(union),
            path.tail,
          );
        },
        leaf: (leaf) => throw Exception('tried to access data in type tree at unknown location'),
      );
    }
  }

  static Object instantiate(Object typeTree, Object data) {
    return treeCases(
      typeTree,
      record: (record) => record.mapValues((k, v) => instantiate(v, data)),
      union: (union) => UnionTag.mk(
        union.entries.first.key as ID,
        instantiate(union.entries.first.value, data),
      ),
      leaf: (leaf) => data,
    );
  }
}

abstract class InterfaceDef {
  static final IDID = ID('ID');
  static final treeID = ID('tree');

  static final def = TypeDef.record('InterfaceDef', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    treeID: TypeTree.mk('tree', Literal.mk(Type.type, TypeTree.type)),
  });
  static final type = TypeDef.asType(def);

  static Dict mk(Dict members, {ID? id}) => Dict({IDID: id ?? ID(), treeID: members});
  static Object record(String name, dart.Map<ID, Dict> members, {ID? id}) =>
      InterfaceDef.mk(TypeTree.record(name, members), id: id);
  static Dict union(String name, dart.Map<ID, Dict> cases, {ID? id}) =>
      InterfaceDef.mk(TypeTree.union(name, cases), id: id);

  static ID id(Object ifaceDef) => (ifaceDef as Dict)[IDID].unwrap! as ID;
  static Object members(Object ifaceDef) => (ifaceDef as Dict)[treeID].unwrap!;

  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: type,
    typeCheck: Fn.from(
      argName: 'interfaceDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Union.mkExpr(
            Vec([ModuleDef.type, Binding.type]),
            Binding.type,
            Construct.mk(
              Binding.type,
              Dict({
                Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
                Binding.nameID: RecordAccess.mk(
                  target: RecordAccess.mk(target: arg, member: treeID),
                  member: TypeTree.nameID,
                ),
                Binding.valueTypeID: Literal.mk(Type.type, type),
                Binding.valueID: Option.noneExpr(type),
              }),
            ),
          ),
        ]),
      ),
    ),
    bindings: Fn.from(
      argName: 'interfaceDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Union.mkExpr(
            Vec([ModuleDef.type, Binding.type]),
            Binding.type,
            Construct.mk(
              Binding.type,
              Dict({
                Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
                Binding.nameID: RecordAccess.mk(
                  target: RecordAccess.mk(target: arg, member: treeID),
                  member: TypeTree.nameID,
                ),
                Binding.valueTypeID: Literal.mk(Type.type, type),
                Binding.valueID: Option.someExpr(type, arg),
              }),
            ),
          ),
        ]),
      ),
    ),
  );
  static final moduleDefImpl = ImplDef.asImpl(moduleDefImplDef);

  static Object mkDef(Object def) => ModuleDef.mk(impl: moduleDefImpl, data: def);
}

abstract class ImplDef {
  static final IDID = ID('ID');
  static final implementedID = ID('implemented');
  static final membersID = ID('members');

  static final def = TypeDef.record('ImplDef', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    implementedID: TypeTree.mk('implemented', Literal.mk(Type.type, ID.type)),
    membersID: TypeTree.mk('members', Literal.mk(Type.type, Any.type)),
  });
  static Object type([ID? implemented]) => TypeDef.asType(
        def,
        properties: Vec([
          if (implemented != null)
            MemberHas.mk(path: Vec([IDID]), property: Equals.mk(ID.type, implemented)),
        ]),
      );

  static Dict mk({ID? id, required ID implemented, required Object members}) =>
      Dict({IDID: id ?? ID(), implementedID: implemented, membersID: members});

  static Object members(Object implDef) => (implDef as Dict)[membersID].unwrap!;

  static Dict asImpl(Object implDef) => Impl.mk((implDef as Dict)[IDID].unwrap! as ID);

  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: type(),
    typeCheck: Fn.from(
      argName: 'implDef',
      type: Fn.type(argType: type(), returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Union.mkExpr(
            Vec([ModuleDef.type, Binding.type]),
            Binding.type,
            Construct.mk(
              Binding.type,
              Dict({
                Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
                Binding.nameID: Literal.mk(text, 'impl'),
                Binding.valueTypeID: Literal.mk(Type.type, type()),
                Binding.valueID: Option.noneExpr(type()),
              }),
            ),
          ),
        ]),
      ),
    ),
    bindings: Fn.from(
      argName: 'typeDef',
      type: Fn.type(argType: type(), returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Union.mkExpr(
            Vec([ModuleDef.type, Binding.type]),
            Binding.type,
            Construct.mk(
              Binding.type,
              Dict({
                Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
                Binding.nameID: Literal.mk(text, 'impl'),
                Binding.valueTypeID: Literal.mk(Type.type, type()),
                Binding.valueID: Option.someExpr(type(), arg),
              }),
            ),
          ),
        ]),
      ),
    ),
  );
  static final moduleDefImpl = ImplDef.asImpl(moduleDefImplDef);

  static Object mkDef(Object def) => ModuleDef.mk(impl: moduleDefImpl, data: def);

  static Object asImplObj(Ctx ctx, Object interfaceDef, Object implDef) {
    Object recurse(Object typeTree, Object dataTree) {
      return TypeTree.treeCases(
        typeTree,
        record: (record) => record.mapValues(
          (k, v) => recurse(v, (dataTree as Dict)[k].unwrap!),
        ),
        union: (union) => throw Exception('impl unionnnn'),
        leaf: (leaf) => eval(ctx, dataTree),
      );
    }

    return recurse(InterfaceDef.members(interfaceDef), ImplDef.members(implDef));
  }

  static ID id(Object impl) => (impl as Dict)[IDID].unwrap! as ID;
}

abstract class Impl {
  static final IDID = ID('ID');

  static final def =
      TypeDef.record('Impl', {IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type))});

  static Dict mk(ID id) => Dict({IDID: id});

  static Object type(ID id, {Vec properties = const Vec()}) => TypeDef.asType(
        def,
        properties: Vec([
          MemberHas.mk(path: Vec([IDID]), property: Equals.mk(ID.type, id)),
          ...properties.map((property) => ImplHas.mk(property: property)),
        ]),
      );

  static ID id(Object impl) => (impl as Dict)[IDID].unwrap! as ID;
}

abstract class Union {
  static final possibleTypesID = ID('dataType');
  static final thisTypeID = ID('thisType');
  static final valueID = ID('value');

  static final def = TypeDef.record('Union', {
    possibleTypesID: TypeTree.mk('possibleTypes', Literal.mk(Type.type, List.type(Type.type))),
    thisTypeID: TypeTree.mk('thisType', Literal.mk(Type.type, Type.type)),
    valueID: TypeTree.mk('value', RecordAccess.mk(target: thisDef, member: thisTypeID)),
  });

  static Object mk(Vec possibleTypes, Object thisType, Object value) => Dict({
        possibleTypesID: possibleTypes,
        thisTypeID: thisType,
        valueID: value,
      });

  static Object mkExpr(Vec possibleTypes, Object thisType, Object value) => Construct.mk(
        TypeDef.asType(def),
        Dict({
          possibleTypesID: Literal.mk(List.type(Type.type), possibleTypes),
          thisTypeID: Literal.mk(Type.type, thisType),
          valueID: value,
        }),
      );

  static Object type(Vec possibleTypes) => TypeDef.asType(
        def,
        properties: Vec([
          MemberHas.mk(
              path: Vec([possibleTypesID]),
              property: Equals.mk(List.type(Type.type), possibleTypes))
        ]),
      );

  static T cases<T>(Object union, dart.Map<Object, T Function(Object)> types) {
    return types[(union as Dict)[thisTypeID].unwrap!]!(union[valueID].unwrap!);
  }
}

abstract class Option {
  static final dataTypeID = ID('dataType');
  static final valueID = ID('value');
  static final someID = ID('some');
  static final noneID = ID('none');

  static final def = TypeDef.record('Option', {
    dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    valueID: TypeTree.union('value', {
      someID: TypeTree.mk('some', RecordAccess.mk(target: thisDef, member: dataTypeID)),
      noneID: TypeTree.unit('none'),
    }),
  });

  static Object type(Object dataType) => TypeDef.asType(
        def,
        properties: Vec([
          MemberHas.mk(
            path: Vec([dataTypeID]),
            property: Equals.mk(Type.type, dataType),
          )
        ]),
      );

  static Object typeExpr(Object dataType) => Type.mkExpr(Type.id(type(unit)),
      properties: List.mkExpr(
        TypeProperty.type,
        Vec([
          MemberHas.mkExpr(
            path: Literal.mk(List.type(ID.type), Vec([dataTypeID])),
            property: Equals.mkExpr(Literal.mk(Type.type, Type.type), dataType),
          )
        ]),
      ));

  static T cases<T>(
    Object option, {
    required T Function(Object) some,
    required T Function() none,
  }) {
    final value = (option as Dict)[valueID].unwrap!;
    return UnionTag.tag(value) == someID ? some(UnionTag.value(value)) : none();
  }

  static final _noneUnionTag = UnionTag.mk(noneID, const Dict());
  static Object mk(Object dataType, [Object? value]) => Dict({
        dataTypeID: dataType,
        valueID: value == null ? _noneUnionTag : UnionTag.mk(someID, value),
      });

  static Object someExpr(Object dataType, Object value) => Construct.mk(
        Option.type(dataType),
        Dict({
          dataTypeID: Literal.mk(Type.type, dataType),
          valueID: UnionTag.mk(someID, value),
        }),
      );

  static Object noneExpr(Object dataType) => Construct.mk(
        Option.type(dataType),
        Dict({
          dataTypeID: Literal.mk(Type.type, dataType),
          valueID: UnionTag.mk(noneID, const Dict()),
        }),
      );

  static Object unwrap(Object option) =>
      Option.cases(option, some: (v) => v, none: () => throw Exception());
}

abstract class Expr {
  static final dataTypeID = ID('dataType');
  static final evalTypeID = ID('evalType');
  static final evalExprID = ID('evalExpr');

  static final interfaceID = ID('interface');
  static final interfaceDef = InterfaceDef.record(
    'ExprImplDef',
    {
      dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
      evalTypeID: TypeTree.mk(
        'type',
        Fn.typeExpr(
          argType: InterfaceAccess.mk(target: thisDef, member: dataTypeID),
          returnType: Literal.mk(Type.type, Option.type(Type.type)),
        ),
      ),
      evalExprID: TypeTree.mk(
        'eval',
        Fn.typeExpr(
          argType: InterfaceAccess.mk(target: thisDef, member: dataTypeID),
          returnType: Literal.mk(Type.type, Any.type),
        ),
      )
    },
    id: interfaceID,
  );

  static Object mkImpl({
    required Object dataType,
    required Object type,
    required Object eval,
    ID? id,
  }) =>
      ImplDef.mk(
        id: id ?? ID(),
        implemented: interfaceID,
        members: Dict({
          dataTypeID: Literal.mk(Type.type, dataType),
          evalTypeID: type,
          evalExprID: eval,
        }),
      );

  static Object dataType(Object exprImpl) => (exprImpl as Dict)[dataTypeID].unwrap!;
  static Object evalType(Object exprImpl) => (exprImpl as Dict)[evalTypeID].unwrap!;
  static Object evalExpr(Object exprImpl) => (exprImpl as Dict)[evalExprID].unwrap!;

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final _defID = ID('_def');
  static final def = TypeDef.record(
    'Expr',
    {
      implID: TypeTree.mk('impl', Literal.mk(Type.type, Impl.type(Expr.interfaceID))),
      dataID: TypeTree.mk(
        'data',
        InterfaceAccess.mk(
          target: RecordAccess.mk(target: thisDef, member: implID),
          member: Expr.dataTypeID,
        ),
      ),
    },
    id: _defID,
  );

  static final type = Type.mk(_defID);

  static Dict mk({required Object data, required Object impl}) =>
      Dict({dataID: data, implID: impl});

  static Object data(Object expr) => (expr as Dict)[dataID].unwrap!;
  static Object impl(Object expr) => (expr as Dict)[implID].unwrap!;

  static Object typeCheckFn = Fn.from(
    argName: 'expr',
    type: Fn.type(argType: Expr.type, returnType: Option.type(Type.type)),
    body: (arg) => FnApp.mk(
      InterfaceAccess.mk(
        target: RecordAccess.mk(target: arg, member: implID),
        member: evalTypeID,
      ),
      RecordAccess.mk(target: arg, member: dataID),
    ),
  );
}

abstract class Assignable {
  static final fromID = ID('from');
  static final toID = ID('to');
  static final whenID = ID('when');
  static final whenFromID = ID('whenFrom');
  static final whenToID = ID('whenTo');
  static final whenTargetDef = TypeDef.record('target', {
    whenFromID: TypeTree.mk('from', Literal.mk(Type.type, unit)),
    whenToID: TypeTree.mk('to', Literal.mk(Type.type, unit)),
  });

  static final def = InterfaceDef.record('Assignable', {
    fromID: TypeTree.mk('from', Literal.mk(Type.type, Type.type)),
    toID: TypeTree.mk('to', Literal.mk(Type.type, Type.type)),
    whenID: TypeTree.mk(
        'when',
        Fn.typeExpr(
          returnType: Literal.mk(Type.type, boolean),
          argType: Literal.mk(Type.type, TypeDef.asType(whenTargetDef)),
        )),
  });
}

abstract class List {
  static final typeID = ID('type');
  static final def = TypeDef.record('List', {
    typeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
  });

  static final mkExprTypeDefID = ID('mkExpr');
  static final mkTypeID = ID('mkType');
  static final mkValuesID = ID('mkValues');
  static final exprDataDef = TypeDef.record(
    'MkList',
    {
      mkTypeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
      mkValuesID: TypeTree.mk('type', Literal.mk(Type.type, List.type(Expr.type))),
    },
    id: mkExprTypeDefID,
  );
  static final mkExprImplDef = Expr.mkImpl(
    dataType: TypeDef.asType(exprDataDef),
    type: Fn.from(
      argName: 'mkListData',
      type: Fn.type(argType: TypeDef.asType(exprDataDef), returnType: Type.type),
      // TODO: actually validate
      body: (arg) => Option.someExpr(
        Type.type,
        RecordAccess.mk(target: arg, member: mkTypeID),
      ),
    ),
    eval: Fn.dart(
      argName: 'mkListData',
      type: Fn.type(argType: TypeDef.asType(exprDataDef), returnType: List.type(Any.type)),
      body: (ctx, arg) => ((arg as Dict)[mkValuesID].unwrap! as Vec).map((expr) => eval(ctx, expr)),
    ),
  );
  static final mkExprImpl = ImplDef.asImpl(mkExprImplDef);

  static Object type(Object type) => TypeDef.asType(def,
      properties: Vec([
        MemberHas.mk(
          path: Vec([typeID]),
          property: Equals.mk(Type.type, type),
        )
      ]));

  static Object mk(Dict type, Vec values) => values;

  static Object mkExpr(Object type, Vec values) =>
      Expr.mk(impl: mkExprImpl, data: Dict({mkTypeID: type, mkValuesID: values}));
}

class Map {
  static final keyID = ID('key');
  static final valueID = ID('value');
  static final def = TypeDef.record('Map', {
    keyID: TypeTree.mk('key', Literal.mk(Type.type, Type.type)),
    valueID: TypeTree.mk('value', Literal.mk(Type.type, Type.type)),
  });

  static Object type(Object key, Object value) => TypeDef.asType(def);

  static Object mk(Type key, Type value, Dict values) => values;

  static final mkExprID = ID('mkExpr');
  static final mkKeyID = ID('mkKey');
  static final mkValueID = ID('mkValue');
  static final mkEntriesID = ID('mkValues');
  static final exprDataDef = TypeDef.record(
    'MkMap',
    {
      mkKeyID: TypeTree.mk('key', Literal.mk(Type.type, Type.type)),
      mkValueID: TypeTree.mk('value', Literal.mk(Type.type, Type.type)),
      mkEntriesID: TypeTree.mk('entries', Literal.mk(Type.type, List.type(List.type(Expr.type)))),
    },
    id: mkExprID,
  );
  static final mkType = Type.mk(mkExprID);

  static final mkExprImplDef = Expr.mkImpl(
    dataType: List.type(Expr.type),
    type: Fn.dart(
      argName: 'mkMapData',
      type: Fn.type(argType: mkType, returnType: Type.type),
      body: (ctx, arg) {
        final keyType = (arg as Dict)[mkKeyID].unwrap!;
        final valueType = arg[mkValueID].unwrap!;

        for (final entry in arg[mkEntriesID].unwrap as Vec) {
          if (typeCheck(ctx, (entry as Vec)[0]) != Option.mk(Type.type, keyType)) {
            return Option.mk(Type.type);
          }
          if (typeCheck(ctx, entry[1]) != Option.mk(Type.type, valueType)) {
            return Option.mk(Type.type);
          }
        }
        return Option.mk(
          Type.type,
          Map.type(keyType, valueType),
        );
      },
    ),
    eval: Fn.dart(
      argName: 'mkMapData',
      type: Fn.type(argType: List.type(Expr.type), returnType: List.type(Any.type)),
      body: (ctx, arg) => Dict({
        for (final entry in (arg as Dict)[mkEntriesID] as Vec)
          eval(ctx, (entry as Vec)[0]): eval(ctx, entry[1])
      }),
    ),
  );
  static Object mkExpr(Type key, Type value, Object entries) => Expr.mk(
        impl: ImplDef.asImpl(mkExprImplDef),
        data: Dict({mkKeyID: key, mkValueID: value, mkEntriesID: entries}),
      );
}

abstract class Any {
  static final typeID = ID('type');
  static final valueID = ID('value');

  static final def = TypeDef.record('Any', {
    typeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
    valueID: TypeTree.mk('valueID', RecordAccess.mk(target: thisDef, member: typeID)),
  });
  static final type = TypeDef.asType(def);

  static Object getType(Object any) => (any as Dict)[typeID].unwrap!;
  static Object getValue(Object any) => (any as Dict)[valueID].unwrap!;
}

final textDef = TypeDef.unit('Text');
final text = TypeDef.asType(textDef);
final numberDef = TypeDef.unit('Number');
final number = TypeDef.asType(numberDef);
final booleanDef = TypeDef.unit('Boolean');
final boolean = TypeDef.asType(booleanDef);
final unitDef = TypeDef.unit('Unit');
final unit = TypeDef.asType(unitDef);
final bottomDef = TypeDef.mk(TypeTree.union('Bottom', const {}));
final bottom = TypeDef.asType(bottomDef);

abstract class Fn extends Expr {
  static final argIDID = ID('argID');
  static final argNameID = ID('argName');
  static final fnTypeID = ID('fnType');
  static final argTypeID = ID('argType');
  static final returnTypeID = ID('returnType');
  static final bodyID = ID('body');
  static final palID = ID('pal');
  static final dartID = ID('dart');

  static final dataDef = TypeDef.mk(TypeTree.record('Fn', {
    argIDID: TypeTree.mk('argID', Literal.mk(Type.type, ID.type)),
    argNameID: TypeTree.mk('argName', Literal.mk(Type.type, text)),
    fnTypeID: TypeTree.record('type', {
      argTypeID: TypeTree.mk('argType', Literal.mk(Type.type, Type.type)),
      returnTypeID: TypeTree.mk('returnType', Literal.mk(Type.type, Type.type)),
    }),
    bodyID: TypeTree.union('body', {
      palID: TypeTree.mk('pal', Literal.mk(Type.type, Expr.type)),
      dartID: TypeTree.mk('dart', Literal.mk(Type.type, Any.type)),
    }),
  }));

  static final _implID = ID('FnExprImpl');
  static final typeFn = Fn.dart(
    argName: 'fnData',
    type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
    body: (ctx, fn) {
      return Fn.bodyCases(
        fn,
        pal: (body) {
          final argID = Fn.argID(fn);
          final argType = Fn.argType(fn);
          final bodyType = typeCheck(
            ctx.withBinding(Binding.mk(id: argID, type: argType, name: Fn.argName(fn))),
            body,
          );
          return Option.cases(
            bodyType,
            some: (bodyType) {
              if (bodyType == returnType(fn)) {
                return Option.mk(
                  Type.type,
                  Fn.type(argType: argType, returnType: returnType(fn)),
                );
              } else {
                return Option.mk(Type.type);
              }
            },
            none: () => Option.mk(Type.type),
          );
        },
        dart: (_) => Option.mk(Type.type, _fnToType(fn)),
      );
    },
  );
  static final evalFn = Fn.dart(
    argName: 'fnData',
    type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Any.type),
    body: (ctx, arg) => arg,
  );
  static final exprImplDef = Expr.mkImpl(
    id: _implID,
    dataType: TypeDef.asType(dataDef),
    type: typeFn,
    eval: evalFn,
  );
  static final exprImpl = Impl.mk(_implID);
  static final exprImplObj = Dict({
    Expr.dataTypeID: TypeDef.asType(dataDef),
    Expr.evalTypeID: Expr.data(typeFn),
    Expr.evalExprID: Expr.data(evalFn)
  });

  static Object type({required Object argType, required Object returnType}) => TypeDef.asType(
        dataDef,
        properties: Vec([
          MemberHas.mk(
            path: Vec([fnTypeID, argTypeID]),
            property: Equals.mk(Type.type, argType),
          ),
          MemberHas.mk(
            path: Vec([fnTypeID, returnTypeID]),
            property: Equals.mk(Type.type, returnType),
          ),
        ]),
      );

  static Object typeExpr({required Object argType, required Object returnType}) => Type.mkExpr(
        TypeDef.id(dataDef),
        properties: List.mkExpr(
          TypeProperty.type,
          Vec([
            MemberHas.mkExpr(
              path: Literal.mk(List.type(ID.type), Vec([fnTypeID, argTypeID])),
              property: Equals.mkExpr(Literal.mk(Type.type, Type.type), argType),
            ),
            MemberHas.mkExpr(
              path: Literal.mk(List.type(ID.type), Vec([fnTypeID, returnTypeID])),
              property: Equals.mkExpr(Literal.mk(Type.type, Type.type), returnType),
            ),
          ]),
        ),
      );

  static Object _fnTypeToDict(Object type) {
    final properties = Type.properties(type);
    Object getType(ID memberID) {
      final prop = properties.firstWhere((prop) {
        if (Impl.id(TypeProperty.impl(prop)) != MemberHas.implID) return false;
        return MemberHas.path(TypeProperty.data(prop)).last == memberID;
      });
      return Equals.equalTo(TypeProperty.data(MemberHas.property(TypeProperty.data(prop))));
    }

    return Dict({
      for (final id in [argTypeID, returnTypeID]) id: getType(id)
    });
  }

  static Object _fnToType(Object fn) => Fn.type(argType: argType(fn), returnType: returnType(fn));

  static Dict mk({
    ID? argID,
    required String argName,
    required Object type,
    required Object body,
  }) =>
      Expr.mk(
        data: Dict({
          argIDID: argID ?? ID(argName),
          argNameID: argName,
          fnTypeID: _fnTypeToDict(type),
          bodyID: UnionTag.mk(palID, body)
        }),
        impl: exprImpl,
      );

  static Object dart({
    ID? argID,
    required String argName,
    required Object type,
    required Object Function(Ctx, Object) body,
  }) =>
      Expr.mk(
        data: Dict({
          argIDID: argID ?? ID(argName),
          argNameID: argName,
          fnTypeID: _fnTypeToDict(type),
          bodyID: UnionTag.mk(dartID, body)
        }),
        impl: exprImpl,
      );

  static Object from({
    required String argName,
    required Object type,
    required Object Function(Object) body,
  }) {
    final argID = ID(argName);
    return Fn.mk(argID: argID, argName: argName, type: type, body: body(Var.mk(argID)));
  }

  static ID argID(Object fn) => (fn as Dict)[argIDID].unwrap! as ID;
  static String argName(Object fn) => (fn as Dict)[argNameID].unwrap! as String;
  static Object fnType(Object fn) => (fn as Dict)[fnTypeID].unwrap!;
  static Object argType(Object fn) => (fnType(fn) as Dict)[argTypeID].unwrap!;
  static Object returnType(Object fn) => (fnType(fn) as Dict)[returnTypeID].unwrap!;
  static Object body(Object fn) => (fn as Dict)[bodyID].unwrap!;
  static Object bodyCases(
    Object fn, {
    required Object Function(Object) pal,
    required Object Function(Object) dart,
  }) {
    final body = (fn as Dict)[bodyID].unwrap!;
    if (UnionTag.tag(body) == palID) {
      return pal(UnionTag.value(body));
    } else {
      return dart(UnionTag.value(body));
    }
  }
}

abstract class FnApp extends Expr {
  static final fnID = ID('fn');
  static final argID = ID('arg');

  static final dataDef = TypeDef.mk(TypeTree.record('FnApp', {
    fnID: TypeTree.mk('fn', Literal.mk(Type.type, Expr.type)),
    argID: TypeTree.mk('arg', Literal.mk(Type.type, Expr.type)),
  }));

  static final exprImplDef = Expr.mkImpl(
    dataType: TypeDef.asType(dataDef),
    type: Fn.dart(
      argName: 'fnAppData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
      // TODO: need to eval the fn expr
      body: (ctx, fnApp) {
        final fnExpr = fn(fnApp);
        return Option.cases(
          typeCheck(ctx, fnExpr),
          none: () => Option.mk(Type.type),
          some: (fnType) {
            return Option.cases(
              typeCheck(ctx, arg(fnApp)),
              none: () => Option.mk(Type.type),
              some: (argType) {
                if (argType == Type.memberEquals(fnType, [Fn.fnTypeID, Fn.argTypeID])) {
                  return Option.mk(
                    Type.type,
                    Type.memberEquals(fnType, [Fn.fnTypeID, Fn.returnTypeID]),
                  );
                } else {
                  return Option.mk(Type.type);
                }
              },
            );
          },
        );
      },
    ),
    eval: Fn.dart(
      argName: 'fnAppData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Any.type),
      body: (ctx, data) {
        final fn = eval(ctx, FnApp.fn(data));
        final arg = eval(ctx, FnApp.arg(data));
        return Fn.bodyCases(
          fn,
          pal: (body) => eval(
            ctx.withBinding(Binding.mk(
              id: Fn.argID(fn),
              type: Fn.argType(fn),
              name: Fn.argName(fn),
              value: arg,
            )),
            body,
          ),
          dart: (body) => (body as Object Function(Ctx, Object))(ctx, arg),
        );
      },
    ),
  );
  static final exprImpl = ImplDef.asImpl(exprImplDef);

  static Dict mk(Object fn, Object arg) =>
      Expr.mk(data: Dict({fnID: fn, argID: arg}), impl: exprImpl);

  static Object fn(Object fnApp) => (fnApp as Dict)[fnID].unwrap!;
  static Object arg(Object fnApp) => (fnApp as Dict)[argID].unwrap!;
}

abstract class InterfaceAccess extends Expr {
  static final targetID = ID('target');
  static final memberID = ID('member');

  static final dataDef = TypeDef.mk(TypeTree.record('InterfaceAccess', {
    targetID: TypeTree.mk('target', Literal.mk(Type.type, Expr.type)),
    memberID: TypeTree.mk('member', Literal.mk(Type.type, ID.type)),
  }));

  static final _implID = ID('InterfaceAccessExprImpl');
  static final exprImplDef = Expr.mkImpl(
    dataType: TypeDef.asType(dataDef),
    type: Fn.dart(
      argName: 'ifaceAccessData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
      body: (ctx, arg) {
        return Option.cases(
          typeCheck(ctx, InterfaceAccess.target(arg)),
          none: () => Option.mk(Type.type),
          some: (targetType) {
            final implemented = Type.memberEquals(targetType, [Impl.IDID]);
            final targetInterfaceDef = ctx.getInterface(implemented as ID);
            final implID = ID();
            return TypeTree.treeCases(
              InterfaceDef.members(targetInterfaceDef),
              leaf: (_) => Option.mk(Type.type),
              union: (_) => Option.mk(Type.type),
              record: (recordNode) {
                final member = InterfaceAccess.member(arg);
                final subTree = recordNode[member].unwrap!;
                return Option.mk(
                  Type.type,
                  TypeTree.treeCases(
                    subTree,
                    record: (_) => Option.mk(Type.type),
                    union: (_) => Option.mk(Type.type),
                    leaf: (leafNode) => eval(
                      ctx.withThisDef(Impl.mk(implID)).withImpl(
                            implID,
                            Dict({
                              for (final prop in (Type.properties(targetType)))
                                if (Impl.id(TypeProperty.impl(prop)) == ImplHas.implID)
                                  for (final prop in [ImplHas.property(TypeProperty.data(prop))])
                                    if (Impl.id(TypeProperty.impl(prop)) == MemberHas.implID)
                                      for (final equals in [
                                        TypeProperty.data(
                                            MemberHas.property(TypeProperty.data(prop)))
                                      ])
                                        MemberHas.path(TypeProperty.data(prop)).first:
                                            Equals.equalTo(equals),
                            }),
                          ),
                      leafNode,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ),
    eval: Fn.dart(
      argName: 'ifaceAccessData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Any.type),
      body: (ctx, data) {
        final impl = ctx.getImpl(Impl.id(eval(ctx, target(data))));
        return (impl as Dict)[member(data)].unwrap!;
      },
    ),
  );
  static final exprImpl = Impl.mk(_implID);

  static Dict mk({required Object target, required Object member}) =>
      Expr.mk(data: Dict({targetID: target, memberID: member}), impl: exprImpl);

  static Object target(Object interfaceAccess) => (interfaceAccess as Dict)[targetID].unwrap!;
  static ID member(Object interfaceAccess) => (interfaceAccess as Dict)[memberID].unwrap! as ID;
}

abstract class Construct extends Expr {
  static final dataTypeID = ID('dataType');
  static final treeID = ID('tree');

  static final dataDef = TypeDef.mk(TypeTree.record('Construct', {
    dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    treeID: TypeTree.mk('tree', Literal.mk(Type.type, Any.type)),
  }));
  static final type = TypeDef.asType(dataDef);

  static final implID = ID('impl');
  static final implDef = Expr.mkImpl(
    id: implID,
    dataType: TypeDef.asType(dataDef),
    type: Fn.dart(
      argName: 'constructData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Option.type(Type.type)),
      body: (ctx, arg) {
        final typeDef = ctx.getType(Type.id(dataType(arg)));
        bool valid(Object typeTree, Object data) {
          return TypeTree.treeCases(
            typeTree,
            record: (record) {
              if (record.length != (data as Dict).length) return false;
              return record.entries.every((entry) => valid(entry.value, data[entry.key].unwrap!));
            },
            union: (union) {
              if (!(data as Dict).containsKey(UnionTag.tagID)) return false;
              if (!union.containsKey(UnionTag.tag(data))) return false;
              return union[UnionTag.tag(data)]
                  .map((subTree) => valid(subTree, UnionTag.value(data)))
                  .orElse(false);
            },
            leaf: (typeExpr) => Option.cases(
              typeCheck(ctx, data),
              some: (type) => eval(ctx.withThisDef(dataType(arg)), typeExpr) == type,
              none: () => false,
            ),
          );
        }

        if (valid(TypeDef.tree(typeDef), tree(arg))) {
          return Option.mk(Type.type, dataType(arg));
        } else {
          return Option.mk(Type.type);
        }
      },
    ),
    eval: Fn.dart(
      argName: 'constructData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Any.type),
      body: (ctx, arg) {
        Object doConstruct(Object typeTree, Object dataTree) {
          return TypeTree.treeCases(
            typeTree,
            record: (record) {
              return Dict({
                for (final elem in (dataTree as Dict).entries)
                  elem.key: doConstruct(record[elem.key].unwrap!, elem.value)
              });
            },
            union: (union) {
              return UnionTag.mk(
                UnionTag.tag(dataTree),
                doConstruct(union[UnionTag.tag(dataTree)].unwrap!, UnionTag.value(dataTree)),
              );
            },
            leaf: (_) {
              return eval(ctx, dataTree);
            },
          );
        }

        return doConstruct(TypeDef.tree(ctx.getType(Type.id(dataType(arg)))), tree(arg));
      },
    ),
  );
  static final impl = Impl.mk(implID);

  static Object dataType(Object construct) => (construct as Dict)[dataTypeID].unwrap!;
  static Object tree(Object construct) => (construct as Dict)[treeID].unwrap!;

  static Object mk(Object dataType, Object tree) => Expr.mk(
        impl: impl,
        data: Dict({dataTypeID: dataType, treeID: tree}),
      );
}

abstract class RecordAccess extends Expr {
  static final targetID = ID('target');
  static final memberID = ID('member');

  static final dataDef = TypeDef.mk(TypeTree.record('RecordAccess', {
    targetID: TypeTree.mk('target', Literal.mk(Type.type, Expr.type)),
    memberID: TypeTree.mk('accessed', Literal.mk(Type.type, ID.type)),
  }));

  static final exprImplID = ID('exprImpl');
  static final exprImplDef = Expr.mkImpl(
    id: exprImplID,
    dataType: TypeDef.asType(dataDef),
    type: Fn.dart(
      argName: 'recordAccessData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
      body: (ctx, arg) {
        return Option.cases(
          typeCheck(ctx, RecordAccess.target(arg)),
          none: () => Option.mk(Type.type),
          some: (targetType) {
            final targetTypeDef = ctx.getType(Type.id(targetType));
            final path = Type.path(targetType);
            final treeAt = TypeTree.treeAt(TypeDef.tree(targetTypeDef), path);
            return TypeTree.treeCases(
              treeAt,
              leaf: (_) => Option.mk(Type.type),
              union: (_) => Option.mk(Type.type),
              record: (recordNode) {
                final member = RecordAccess.member(arg);
                final subTree = recordNode[member].unwrap!;
                return Option.mk(
                  Type.type,
                  TypeTree.treeCases(
                    subTree,
                    record: (_) => (targetType as Dict).put(Type.pathID, path.add(member)),
                    union: (_) => (targetType as Dict).put(Type.pathID, path.add(member)),
                    leaf: (leafNode) => eval(
                      ctx.withThisDef(
                        (targetType as Dict).put(Type.pathID, const Vec()),
                      ),
                      leafNode,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ),
    eval: Fn.dart(
      argName: 'recordAccessData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Any.type),
      body: (ctx, data) {
        return (eval(ctx, target(data)) as Dict)[member(data)].unwrap!;
      },
    ),
  );
  static final exprImpl = Impl.mk(exprImplID);

  static Dict mk({required Object target, required Object member}) => Expr.mk(
        data: Dict({targetID: target, memberID: member}),
        impl: exprImpl,
      );

  static Object target(Object dataAccess) => (dataAccess as Dict)[targetID].unwrap!;
  static ID member(Object dataAccess) => (dataAccess as Dict)[memberID].unwrap! as ID;
}

abstract class Literal extends Expr {
  static final typeID = ID('type');
  static final valueID = ID('value');

  static final dataDef = TypeDef.record('Literal', {
    typeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
    valueID: TypeTree.mk('value', RecordAccess.mk(target: thisDef, member: typeID)),
  });

  static final typeFn = Fn.from(
    argName: 'literalData',
    type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
    body: (arg) => Option.someExpr(Type.type, RecordAccess.mk(target: arg, member: typeID)),
  );
  static final evalFn = Fn.dart(
    argName: 'literalData',
    type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Any.type),
    body: (ctx, arg) => (arg as Dict)[valueID].unwrap!,
  );
  static final _implID = ID('LiteralExprImpl');
  static final exprImplDef =
      Expr.mkImpl(id: _implID, dataType: TypeDef.asType(dataDef), type: typeFn, eval: evalFn);
  static final exprImplObj = Dict({
    Expr.dataTypeID: TypeDef.asType(dataDef),
    Expr.evalTypeID: Expr.data(typeFn),
    Expr.evalExprID: Expr.data(evalFn),
  });
  static final exprImpl = Impl.mk(_implID);

  static Dict mk(Object type, Object value) =>
      Expr.mk(impl: exprImpl, data: Dict({typeID: type, valueID: value}));
}

abstract class Var extends Expr {
  static final IDID = ID('ID');
  static final dataDef = TypeDef.record('VarAccess', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
  });
  static final exprImplDef = Expr.mkImpl(
    dataType: TypeDef.asType(dataDef),
    type: Fn.dart(
      argName: 'varData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
      body: (ctx, arg) => Option.cases(
        ctx.getBinding(Var.id(arg)),
        some: (binding) => Option.mk(Type.type, Binding.valueType(binding)),
        none: () => Option.mk(Type.type),
      ),
    ),
    eval: Fn.dart(
      argName: 'varData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Any.type),
      body: (ctx, arg) => Option.cases(
        Binding.value(
          Option.cases(
            ctx.getBinding(Var.id(arg)),
            some: (binding) => binding,
            none: () => throw Exception(),
          ),
        ),
        some: (val) => val,
        none: () => throw Exception('impossible!!'),
      ),
    ),
  );
  static final exprImpl = ImplDef.asImpl(exprImplDef);

  static Dict mk(ID varID) => Expr.mk(data: Dict({IDID: varID}), impl: exprImpl);

  static ID id(Object varAccess) => (varAccess as Dict)[IDID].unwrap! as ID;
}

abstract class ThisDef extends Expr {
  static final dataDef = TypeDef.unit('ThisDef');
  static final _implID = ID('ThisDefExprImpl');
  static final exprImplDef = Expr.mkImpl(
    id: _implID,
    dataType: TypeDef.asType(dataDef),
    type: Fn.dart(
        argName: '_',
        type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
        body: (ctx, _) {
          return Option.cases(
            ctx.thisDef,
            some: (thisDef) => Option.mk(Type.type, thisDef),
            none: () => Option.mk(Type.type),
          );
        }),
    eval: Fn.dart(
      argName: '_',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Any.type),
      body: (ctx, _) =>
          Option.cases(ctx.thisDef, none: () => throw Exception(), some: (thisDef) => thisDef),
    ),
  );
  static final exprImpl = Impl.mk(_implID);

  static Dict _() => Expr.mk(data: const Dict(), impl: exprImpl);
}

final thisDef = ThisDef._();

extension CtxThisDef on Ctx {
  static final _bindingID = ID();
  Ctx withThisDef(Object thisDef) =>
      withBinding(Binding.mk(id: _bindingID, name: 'thisDef', type: Type.type, value: thisDef));
  Object get thisDef =>
      Option.cases(getBinding(_bindingID), some: Binding.value, none: () => Option.mk(Type.type));
}

abstract class Placeholder extends Expr {
  static final typeDef = TypeDef.unit('Placeholder');

  static final exprImplDef = Expr.mkImpl(
    dataType: TypeDef.asType(typeDef),
    type: Fn.from(
      argName: '_',
      type: Fn.type(
        argType: TypeDef.asType(typeDef),
        returnType: Option.type(Type.type),
      ),
      body: (_) => Option.noneExpr(Type.type),
    ),
    eval: Fn.dart(
      argName: '_',
      type: Fn.type(
        argType: TypeDef.asType(typeDef),
        returnType: bottom,
      ),
      body: (_, __) => throw Exception("don't evaluate a placeholder u fool!"),
    ),
  );
  static final exprImpl = ImplDef.asImpl(exprImplDef);
}

final placeholder = Expr.mk(data: const Dict(), impl: Placeholder.exprImpl);

extension CtxType on Ctx {
  Ctx withTypes(Iterable<Object> typeDefs) => typeDefs.fold(this, (ctx, def) => ctx.withType(def));
  Ctx withType(Object typeDef) => withBinding(
        Binding.mk(
          id: TypeDef.id(typeDef),
          type: TypeDef.type,
          name: TypeTree.name(TypeDef.tree(typeDef)),
          value: typeDef,
        ),
      );
  Object getType(ID id) => Option.unwrap(Binding.value(Option.unwrap(getBinding(id))));
  Iterable<Object> get getTypes => getBindings.expand((binding) => [
        if (Binding.valueType(binding) == TypeDef.type) Option.unwrap(Binding.value(binding)),
      ]);

  Ctx withInterfaces(Iterable<Object> interfaceDefs) =>
      interfaceDefs.fold(this, (ctx, def) => ctx.withInterface(def));
  Ctx withInterface(Object interface) => withBinding(
        Binding.mk(
          id: InterfaceDef.id(interface),
          type: InterfaceDef.type,
          name: TypeTree.name(InterfaceDef.members(interface)),
          value: interface,
        ),
      );
  Object getInterface(ID id) => Option.unwrap(Binding.value(Option.unwrap(getBinding(id))));

  Ctx withImpls(dart.Map<ID, Object> implDefs) =>
      implDefs.entries.fold(this, (ctx, entry) => ctx.withImpl(entry.key, entry.value));
  Ctx withImpl(ID id, Object impl) => withBinding(
        Binding.mk(
          id: id,
          type: ImplDef.type,
          name: 'impl',
          value: impl,
        ),
      );
  Object getImpl(ID id) => Option.unwrap(Binding.value(Option.unwrap(getBinding(id))));
}

abstract class Binding {
  static final IDID = ID('ID');
  static final valueTypeID = ID('type');
  static final nameID = ID('name');
  static final valueID = ID('value');

  static final def = TypeDef.record('Binding', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    valueTypeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
    nameID: TypeTree.mk('name', Literal.mk(Type.type, text)),
    valueID: TypeTree.mk(
      'value',
      Option.typeExpr(RecordAccess.mk(target: thisDef, member: valueTypeID)),
    ),
  });
  static final type = TypeDef.asType(def);

  static Object mk({
    required ID id,
    required Object type,
    required String name,
    Object? value,
  }) =>
      Dict({IDID: id, valueTypeID: type, nameID: name, valueID: Option.mk(type, value)});

  static Object mkExpr({
    required Object id,
    required Object type,
    required Object name,
    required Object value,
  }) =>
      Dict({
        IDID: id,
        valueTypeID: type,
        nameID: name,
        valueID: value,
      });

  static ID id(Object binding) => (binding as Dict)[IDID].unwrap! as ID;
  static Object valueType(Object binding) => (binding as Dict)[valueTypeID].unwrap!;
  static String name(Object binding) => (binding as Dict)[nameID].unwrap! as String;
  static Object value(Object binding) => (binding as Dict)[valueID].unwrap!;
}

class BindingCtx extends CtxElement {
  final reified.Dict<ID, Object> bindings;

  const BindingCtx([this.bindings = const reified.Dict()]);
}

extension CtxBinding on Ctx {
  Ctx withBinding(Object binding) => withElement(
        BindingCtx(
          (get<BindingCtx>() ?? const BindingCtx()).bindings.put(Binding.id(binding), binding),
        ),
      );
  Object getBinding(ID id) =>
      Option.mk(Binding.type, (get<BindingCtx>() ?? const BindingCtx()).bindings[id].unwrap);
  Iterable<Object> get getBindings => (get<BindingCtx>() ?? const BindingCtx()).bindings.values;
}

final _bootstrapCtx = Ctx.empty.withImpls({
  Impl.id(Literal.exprImpl): Literal.exprImplObj,
  Impl.id(Fn.exprImpl): Fn.exprImplObj,
});
final coreCtx = Ctx.empty.withTypes([
  ID.def,
  Type.def,
  TypeDef.def,
  TypeTree.def,
  UnionTag.def,
  InterfaceDef.def,
  ImplDef.def,
  Impl.def,
  Expr.def,
  List.def,
  Map.def,
  Construct.dataDef,
  Option.def,
  ID.def,
  numberDef,
  textDef,
  Fn.dataDef,
  TypeProperty.typeDef,
  MemberHas.typeDef,
  Equals.typeDef,
  ModuleDef.typeDef,
  Module.def,
  Literal.dataDef,
  InterfaceAccess.dataDef,
  RecordAccess.dataDef,
  ThisDef.dataDef,
  ImplHas.typeDef,
  Binding.def,
  List.exprDataDef,
  Map.exprDataDef,
  FnApp.dataDef,
  Var.dataDef,
  Placeholder.typeDef,
  Union.def,
]).withInterfaces([
  Expr.interfaceDef,
  TypeProperty.interfaceDef,
  ModuleDef.interfaceDef,
]).withImpls({
  // exprs
  Impl.id(Var.exprImpl): ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, Var.exprImplDef),
  Impl.id(Literal.exprImpl):
      ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, Literal.exprImplDef),
  Impl.id(InterfaceAccess.exprImpl):
      ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, InterfaceAccess.exprImplDef),
  Impl.id(Construct.impl): ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, Construct.implDef),
  Impl.id(RecordAccess.exprImpl):
      ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, RecordAccess.exprImplDef),
  Impl.id(Fn.exprImpl): ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, Fn.exprImplDef),
  Impl.id(FnApp.exprImpl): ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, FnApp.exprImplDef),
  Impl.id(ThisDef.exprImpl):
      ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, ThisDef.exprImplDef),
  Impl.id(Placeholder.exprImpl):
      ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, Placeholder.exprImplDef),
  Impl.id(List.mkExprImpl): ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, List.mkExprImplDef),
  ImplDef.id(Map.mkExprImplDef):
      ImplDef.asImplObj(_bootstrapCtx, Expr.interfaceDef, Map.mkExprImplDef),
  // type properties
  Impl.id(MemberHas.impl):
      ImplDef.asImplObj(_bootstrapCtx, TypeProperty.interfaceDef, MemberHas.propImplDef),
  // module defs
  Impl.id(TypeDef.moduleDefImpl):
      ImplDef.asImplObj(_bootstrapCtx, ModuleDef.interfaceDef, TypeDef.moduleDefImplDef),
  Impl.id(InterfaceDef.moduleDefImpl):
      ImplDef.asImplObj(_bootstrapCtx, ModuleDef.interfaceDef, InterfaceDef.moduleDefImplDef),
  Impl.id(ImplDef.moduleDefImpl):
      ImplDef.asImplObj(_bootstrapCtx, ModuleDef.interfaceDef, ImplDef.moduleDefImplDef),
  ImplDef.id(ValueDef.moduleDefImplDef):
      ImplDef.asImplObj(_bootstrapCtx, ModuleDef.interfaceDef, ValueDef.moduleDefImplDef),
});

Object eval(Ctx ctx, Object expr) {
  final data = Expr.data(expr);
  final impl = ctx.getImpl(Impl.id(Expr.impl(expr)));
  final dataType = Expr.dataType(impl);
  final evalExprFn = Expr.evalExpr(impl);
  return Fn.bodyCases(
    evalExprFn,
    pal: (bodyExpr) {
      return eval(
        ctx.withBinding(Binding.mk(
          id: Fn.argID(evalExprFn),
          type: dataType,
          name: Fn.argName(evalExprFn),
          value: data,
        )),
        bodyExpr,
      );
    },
    dart: (bodyFn) {
      return (bodyFn as Object Function(Ctx, Object))(ctx, data);
    },
  );
}

Object typeCheck(Ctx ctx, Object expr) => eval(
      ctx,
      FnApp.mk(Expr.typeCheckFn, Literal.mk(Expr.type, expr)),
    );

final coreModule = Module.mk(
  name: 'core',
  definitions: Vec([
    TypeDef.mkDef(Module.def),
    InterfaceDef.mkDef(ModuleDef.interfaceDef),
    TypeDef.mkDef(ModuleDef.typeDef),
    TypeDef.mkDef(ValueDef.typeDef),
    TypeDef.mkDef(TypeDef.def),
    ImplDef.mkDef(TypeDef.moduleDefImplDef),
    TypeDef.mkDef(Type.def),
    InterfaceDef.mkDef(TypeProperty.interfaceDef),
    TypeDef.mkDef(TypeProperty.typeDef),
    TypeDef.mkDef(Equals.typeDef),
    ImplDef.mkDef(Equals.propImplDef),
    TypeDef.mkDef(ImplHas.typeDef),
    ImplDef.mkDef(ImplHas.propImplDef),
    TypeDef.mkDef(MemberHas.typeDef),
    ImplDef.mkDef(MemberHas.propImplDef),
    TypeDef.mkDef(UnionTag.def),
    TypeDef.mkDef(TypeTree.def),
    TypeDef.mkDef(InterfaceDef.def),
    ImplDef.mkDef(InterfaceDef.moduleDefImplDef),
    TypeDef.mkDef(ImplDef.def),
    ImplDef.mkDef(ImplDef.moduleDefImplDef),
    TypeDef.mkDef(Impl.def),
    TypeDef.mkDef(Option.def),
    TypeDef.mkDef(Expr.def),
    InterfaceDef.mkDef(Expr.interfaceDef),
    TypeDef.mkDef(List.def),
    TypeDef.mkDef(List.exprDataDef),
    ImplDef.mkDef(List.mkExprImplDef),
    TypeDef.mkDef(Map.def),
    TypeDef.mkDef(Map.exprDataDef),
    ImplDef.mkDef(Map.mkExprImplDef),
    TypeDef.mkDef(Any.def),
    TypeDef.mkDef(textDef),
    TypeDef.mkDef(numberDef),
    TypeDef.mkDef(booleanDef),
    TypeDef.mkDef(unitDef),
    TypeDef.mkDef(bottomDef),
    TypeDef.mkDef(Fn.dataDef),
    ImplDef.mkDef(Fn.exprImplDef),
    TypeDef.mkDef(FnApp.dataDef),
    ImplDef.mkDef(FnApp.exprImplDef),
    TypeDef.mkDef(InterfaceAccess.dataDef),
    ImplDef.mkDef(InterfaceAccess.exprImplDef),
    TypeDef.mkDef(Construct.dataDef),
    ImplDef.mkDef(Construct.implDef),
    TypeDef.mkDef(RecordAccess.dataDef),
    ImplDef.mkDef(RecordAccess.exprImplDef),
    TypeDef.mkDef(Literal.dataDef),
    ImplDef.mkDef(Literal.exprImplDef),
    TypeDef.mkDef(Var.dataDef),
    ImplDef.mkDef(Var.exprImplDef),
    TypeDef.mkDef(ThisDef.dataDef),
    ImplDef.mkDef(ThisDef.exprImplDef),
    TypeDef.mkDef(Placeholder.typeDef),
    ImplDef.mkDef(Placeholder.exprImplDef),
    TypeDef.mkDef(Binding.def),
  ]),
);
