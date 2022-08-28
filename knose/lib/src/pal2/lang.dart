import 'dart:core' as dart;
import 'dart:core';
import 'package:ctx/ctx.dart';
import 'package:reified_lenses/reified_lenses.dart';
import 'package:reified_lenses/reified_lenses.dart' as reified;
import 'package:uuid/uuid.dart';

typedef Dict = reified.Dict<Object, Object>;
typedef Vec = reified.Vec<Object>;

class ID extends Comparable<ID> {
  static final def = TypeDef.unit('ID');
  static final type = TypeDef.asType(def);

  static const _uuid = Uuid();

  final String id;
  final String? label;

  ID([this.label]) : id = _uuid.v4();

  ID.from(this.id, this.label);

  @override
  bool operator ==(Object other) => other is ID && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$runtimeType(${label ?? id})';

  @override
  int compareTo(ID other) {
    return id.compareTo(other.id);
  }

  dynamic toJson() => id;
}

abstract class Module {
  static final IDID = ID('ID');
  static final nameID = ID('name');
  static final definitionsID = ID('definitions');

  static final def = TypeDef.record('Module', {
    IDID: TypeTree.mk('id', ID.type),
    nameID: TypeTree.mk('name', text),
    definitionsID: TypeTree.mk('definitions', List.type(ModuleDef.type))
  });
  static final type = TypeDef.asType(def);

  static Object mk({ID? id, required String name, required Vec definitions}) =>
      Dict({IDID: id ?? ID(), nameID: name, definitionsID: definitions});
}

abstract class ModuleDef extends InterfaceDef {
  static final dataTypeID = ID('dataType');
  static final bindingTypesID = ID('bindingTypes');
  static final bindingsID = ID('bindings');
  static final interfaceDef = InterfaceDef.record('ModuleDef', {
    dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    bindingTypesID: TypeTree.mk(
        'bindingTypes',
        Fn.typeExpr(
          argType: RecordAccess.mk(target: thisDef, member: dataTypeID),
          returnType: List.type(Binding.type),
        )),
    bindingsID: TypeTree.mk(
      'bindings',
      Fn.typeExpr(
        argType: RecordAccess.mk(target: thisDef, member: dataTypeID),
        returnType: List.type(Binding.type),
      ),
    ),
  });

  static Object mkImpl({
    required Object dataType,
    required Object bindingTypes,
    required Object bindings,
    ID? id,
  }) =>
      ImplDef.mk(
        implemented: InterfaceDef.id(interfaceDef),
        members: {
          dataTypeID: dataType,
          bindingTypesID: bindingTypes,
          bindingsID: bindings,
        },
      );

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final typeDef = TypeDef.record('ModuleDef', {
    implID: TypeTree.mk('impl', Literal.mk(Type.type, Impl.type)),
    dataID: TypeTree.mk(
        'data',
        InterfaceAccess.mk(
          target: RecordAccess.mk(target: thisDef, member: implID),
          member: dataTypeID,
        )),
  });
  static final type = TypeDef.asType(typeDef);

  static Object mk({required Object impl, required Object data}) =>
      Dict({implID: impl, dataID: data});
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

  static final moduleDefImpl = ModuleDef.mkImpl(
    dataType: Literal.mk(Type.type, type),
    bindingTypes: Fn.from(
      argName: 'typeDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Construct.mk(
            Binding.type,
            Dict({
              Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
              Binding.nameID: RecordAccess.mk(
                target: RecordAccess.mk(target: arg, member: treeID),
                member: TypeTree.nameID,
              ),
              Binding.typeID: Literal.mk(Type.type, type),
              Binding.valueID: Option.noneExpr(type),
            }),
          )
        ]),
      ),
    ),
    bindings: Fn.from(
      argName: 'typeDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Construct.mk(
            Binding.type,
            Dict({
              Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
              Binding.nameID: RecordAccess.mk(
                target: RecordAccess.mk(target: arg, member: treeID),
                member: TypeTree.nameID,
              ),
              Binding.typeID: Literal.mk(Type.type, type),
              Binding.valueID: Option.someExpr(type, arg),
            }),
          )
        ]),
      ),
    ),
  );

  static Object mkDef(Object def) => ModuleDef.mk(impl: ImplDef.asImpl(moduleDefImpl), data: def);
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
      hasID: TypeTree.mk(
        'has',
        Fn.typeExpr(
          argType: InterfaceAccess.mk(target: thisDef, member: dataTypeID),
          returnType: Literal.mk(Type.type, boolean),
        ),
      ),
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
        members: Dict({dataTypeID: dataType, hasID: has}),
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
    equalToID: TypeTree.mk('equalTo', InterfaceAccess.mk(target: thisDef, member: dataTypeID)),
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
    valueID: TypeTree.mk('value', Literal.mk(Type.type, any)),
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
  static final membersID = ID('members');

  static final def = TypeDef.record('InterfaceDef', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    membersID: TypeTree.mk('members', Literal.mk(Type.type, TypeTree.type)),
  });
  static final type = TypeDef.asType(def);

  static Dict mk(Dict members, {ID? id}) => Dict({IDID: id ?? ID(), membersID: members});
  static Dict record(String name, dart.Map<ID, Dict> members, {ID? id}) =>
      InterfaceDef.mk(TypeTree.record(name, members), id: id);
  static Dict union(String name, dart.Map<ID, Dict> cases, {ID? id}) =>
      InterfaceDef.mk(TypeTree.union(name, cases), id: id);

  static ID id(Object ifaceDef) => (ifaceDef as Dict)[IDID].unwrap! as ID;
  static Object members(Object ifaceDef) => (ifaceDef as Dict)[membersID].unwrap!;

  static final moduleDefImpl = ModuleDef.mkImpl(
    dataType: Literal.mk(Type.type, type),
    bindingTypes: Fn.from(
      argName: 'interfaceDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Construct.mk(
            Binding.type,
            Dict({
              Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
              Binding.nameID: RecordAccess.mk(
                target: RecordAccess.mk(target: arg, member: membersID),
                member: TypeTree.nameID,
              ),
              Binding.typeID: Literal.mk(Type.type, type),
              Binding.valueID: Option.noneExpr(type),
            }),
          )
        ]),
      ),
    ),
    bindings: Fn.from(
      argName: 'typeDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Construct.mk(
            Binding.type,
            Dict({
              Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
              Binding.nameID: RecordAccess.mk(
                target: RecordAccess.mk(target: arg, member: membersID),
                member: TypeTree.nameID,
              ),
              Binding.typeID: Literal.mk(Type.type, type),
              Binding.valueID: Option.someExpr(type, arg),
            }),
          )
        ]),
      ),
    ),
  );

  static Object mkDef(Object def) => ModuleDef.mk(impl: ImplDef.asImpl(moduleDefImpl), data: def);
}

abstract class ImplDef {
  static final IDID = ID('ID');
  static final implementedID = ID('implemented');
  static final membersID = ID('members');

  static final def = TypeDef.record('ImplDef', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    implementedID: TypeTree.mk('implemented', Literal.mk(Type.type, ID.type)),
    membersID: TypeTree.mk('members', Literal.mk(Type.type, any)),
  });
  static Object type(ID implemented) => TypeDef.asType(
        def,
        properties: Vec([
          MemberHas.mk(path: Vec([IDID]), property: Equals.mk(ID.type, implemented)),
        ]),
      );

  static Dict mk({ID? id, required ID implemented, required Object members}) =>
      Dict({IDID: id ?? ID(), implementedID: implemented, membersID: members});

  static Object members(Object implDef) => (implDef as Dict)[membersID].unwrap!;

  static Dict asImpl(Object implDef) => Impl.mk((implDef as Dict)[IDID].unwrap! as ID);

  static final moduleDefImpl = ModuleDef.mkImpl(
    dataType: Literal.mk(Type.type, type),
    bindingTypes: Fn.from(
      argName: 'implDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Construct.mk(
            Binding.type,
            Dict({
              Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
              Binding.nameID: Literal.mk(text, 'impl'),
              Binding.typeID: Literal.mk(Type.type, type),
              Binding.valueID: Option.noneExpr(type),
            }),
          )
        ]),
      ),
    ),
    bindings: Fn.from(
      argName: 'typeDef',
      type: Fn.type(argType: type, returnType: List.type(Binding.type)),
      body: (arg) => List.mkExpr(
        Binding.type,
        Vec([
          Construct.mk(
            Binding.type,
            Dict({
              Binding.IDID: RecordAccess.mk(target: arg, member: IDID),
              Binding.nameID: Literal.mk(text, 'impl'),
              Binding.typeID: Literal.mk(Type.type, type),
              Binding.valueID: Option.someExpr(type, arg),
            }),
          )
        ]),
      ),
    ),
  );

  static Object mkDef(Object def) => ModuleDef.mk(impl: ImplDef.asImpl(moduleDefImpl), data: def);
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
          returnType: Literal.mk(Type.type, any),
        ),
      )
    },
    id: interfaceID,
  );

  static Object mkImpl({
    required Object data,
    required Object type,
    required Object eval,
    ID? id,
  }) =>
      ImplDef.mk(
        id: id ?? ID(),
        implemented: interfaceID,
        members: Dict({dataTypeID: data, evalTypeID: Expr.data(type), evalExprID: Expr.data(eval)}),
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
          )),
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
  static final valuesID = ID('values');
  static final def = TypeDef.record('List', {
    typeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
    valuesID: TypeTree.unit('values'),
  });

  static final mkExprID = ID('mkExpr');
  static final mkTypeID = ID('mkType');
  static final mkValuesID = ID('mkValues');
  static final exprDataDef = TypeDef.record(
    'MkList',
    {
      mkTypeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
      mkValuesID: TypeTree.mk('type', Literal.mk(Type.type, List.type(Expr.type))),
    },
    id: mkExprID,
  );
  static final mkExprImpl = Expr.mkImpl(
    data: List.type(Expr.type),
    type: Fn.from(
      argName: 'mkListData',
      type: Fn.type(argType: List.type(Expr.type), returnType: Type.type),
      // TODO: actually validate
      body: (arg) => Option.someExpr(
        Type.type,
        RecordAccess.mk(target: arg, member: mkTypeID),
      ),
    ),
    eval: Fn.dart(
      argName: 'mkListData',
      type: Fn.type(argType: List.type(Expr.type), returnType: List.type(any)),
      body: (ctx, arg) => ((arg as Dict)[mkValuesID] as Vec).map((expr) => eval(ctx, expr)),
    ),
  );

  static Object type(Object type) => TypeDef.asType(def,
      properties: Vec([
        MemberHas.mk(
          path: Vec([typeID]),
          property: Equals.mk(Type.type, type),
        )
      ]));

  static Dict mk(Dict type, Vec values) => Dict({typeID: type, valuesID: values});

  static Object mkExpr(Object type, Vec values) =>
      Expr.mk(impl: Impl.mk(mkExprID), data: Dict({mkTypeID: type, mkValuesID: values}));
}

class Map {
  static final keyID = ID('key');
  static final valueID = ID('value');
  static final valuesID = ID('values');
  static final def = TypeDef.record('Map', {
    keyID: TypeTree.mk('key', Literal.mk(Type.type, Type.type)),
    valueID: TypeTree.mk('value', Literal.mk(Type.type, Type.type)),
    valuesID: TypeTree.unit('values'),
  });

  static Object type(Object key, Object value) => TypeDef.asType(def);

  static Object mk(Type key, Type value, Object values) =>
      Dict({keyID: key, valueID: value, valuesID: values});

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

  static final mkExprImpl = Expr.mkImpl(
    data: List.type(Expr.type),
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
      type: Fn.type(argType: List.type(Expr.type), returnType: List.type(any)),
      body: (ctx, arg) => Dict({
        for (final entry in (arg as Dict)[mkEntriesID] as Vec)
          eval(ctx, (entry as Vec)[0]): eval(ctx, entry[1])
      }),
    ),
  );
  static Object mkExpr(Type key, Type value, Object values) =>
      Dict({keyID: key, valueID: value, valuesID: values});
}

final anyDef = TypeDef.unit('Any');
final any = TypeDef.asType(anyDef);
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
      dartID: TypeTree.mk('dart', Literal.mk(Type.type, any)),
    }),
  }));

  static final _implID = ID('_impl');
  static final exprImplDef = Expr.mkImpl(
    id: _implID,
    data: TypeDef.asType(dataDef),
    type: Fn.dart(
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
                  return Option.mk(Type.type, bodyType);
                } else {
                  return Option.mk(Type.type);
                }
              },
              none: () => Option.mk(Type.type),
            );
          },
          dart: (_) => _fnToType(fn),
        );
      },
    ),
    eval: Fn.from(
      argName: 'fnData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: any),
      body: (arg) => arg,
    ),
  );
  static final exprImpl = Impl.mk(_implID);

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
    data: TypeDef.asType(dataDef),
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
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: any),
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
              value: Optional(arg),
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

  static final _implID = ID('_impl');
  static final exprImplDef = Expr.mkImpl(
    data: TypeDef.asType(dataDef),
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
                            ImplDef.mk(
                              id: implID,
                              implemented: implemented,
                              members: Dict({
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
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: any),
      body: (ctx, data) {
        final implDef = ctx.getImpl(Impl.id(eval(ctx, target(data))));
        return (ImplDef.members(implDef) as Dict)[member(data)].unwrap!;
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
    treeID: TypeTree.mk('tree', Literal.mk(Type.type, TypeTree.type)),
  }));
  static final type = TypeDef.asType(dataDef);

  static final implID = ID('impl');
  static final implDef = Expr.mkImpl(
    id: implID,
    data: TypeDef.asType(dataDef),
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
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: any),
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
    data: TypeDef.asType(dataDef),
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
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: any),
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

  static final _implID = ID('_impl');
  static final exprImplDef = Expr.mkImpl(
    id: _implID,
    data: TypeDef.asType(dataDef),
    // needs data constructor expr
    type: Fn.dart(
      argName: 'literalData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
      body: (ctx, lit) => Option.mk(Type.type, (lit as Dict)[typeID].unwrap!),
    ),
    eval: Fn.from(
      argName: 'literalData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: any),
      body: (arg) => RecordAccess.mk(target: arg, member: valueID),
    ),
  );
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
    data: TypeDef.asType(dataDef),
    type: Fn.dart(
      argName: 'varData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
      body: (ctx, arg) => Option.mk(Type.type, Binding.type(ctx.getBinding(Var.id(arg)))),
    ),
    eval: Fn.dart(
      argName: 'varData',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: any),
      body: (ctx, arg) => Option.cases(
        Binding.value(ctx.getBinding(Var.id(arg))),
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
  static final _implID = ID('_impl');
  static final exprImplDef = Expr.mkImpl(
    id: _implID,
    data: TypeDef.asType(dataDef),
    type: Fn.mk(
      argName: '_',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: Type.type),
      body: Literal.mk(Type.type, TypeDef.type),
    ),
    eval: Fn.dart(
      argName: '_',
      type: Fn.type(argType: TypeDef.asType(dataDef), returnType: any),
      body: (ctx, _) => ctx.thisDef,
    ),
  );
  static final exprImpl = Impl.mk(_implID);

  static Dict _() => Expr.mk(data: const Dict(), impl: exprImpl);
}

final thisDef = ThisDef._();

class ThisDefCtx extends CtxElement {
  final Object thisDef;
  const ThisDefCtx(this.thisDef);
}

extension CtxThisDef on Ctx {
  Ctx withThisDef(Object thisDef) => withElement(ThisDefCtx(thisDef));
  Object get thisDef => get<ThisDefCtx>()!.thisDef;
}

abstract class Placeholder extends Expr {
  static final typeDef = TypeDef.unit('Placeholder');

  static final exprImplDef = Expr.mkImpl(
    data: TypeDef.asType(typeDef),
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

class TypeCtx extends CtxElement {
  final Dict types;
  final Dict impls;
  final Dict interfaces;

  const TypeCtx({
    this.types = const Dict(),
    this.impls = const Dict(),
    this.interfaces = const Dict(),
  });

  TypeCtx withType(ID id, Object type) => TypeCtx(
        types: types.put(id, type),
        impls: impls,
        interfaces: interfaces,
      );

  TypeCtx withImpl(ID id, Object impl) => TypeCtx(
        types: types,
        impls: impls.put(id, impl),
        interfaces: interfaces,
      );

  TypeCtx withInterface(ID id, Object interface) => TypeCtx(
        types: types,
        impls: impls,
        interfaces: interfaces.put(id, interface),
      );
}

extension CtxType on Ctx {
  Ctx withType(ID id, Object type) =>
      withElement((get<TypeCtx>() ?? const TypeCtx()).withType(id, type));
  Object getType(ID id) => (get<TypeCtx>() ?? const TypeCtx()).types[id].unwrap!;
  Iterable<Object> get getTypes => (get<TypeCtx>() ?? const TypeCtx()).types.values;

  Ctx withInterface(ID id, Object interface) =>
      withElement((get<TypeCtx>() ?? const TypeCtx()).withInterface(id, interface));
  Object getInterface(ID id) => (get<TypeCtx>() ?? const TypeCtx()).interfaces[id].unwrap!;

  Ctx withImpl(ID id, Object impl) =>
      withElement((get<TypeCtx>() ?? const TypeCtx()).withImpl(id, impl));
  Object getImpl(ID id) => (get<TypeCtx>() ?? const TypeCtx()).impls[id].unwrap!;
}

abstract class Binding {
  static final IDID = ID('ID');
  static final typeID = ID('type');
  static final nameID = ID('name');
  static final valueID = ID('value');

  static final def = TypeDef.record('Binding', {
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    typeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
    nameID: TypeTree.mk('name', Literal.mk(Type.type, text)),
    valueID: TypeTree.mk(
      'value',
      Option.typeExpr(RecordAccess.mk(target: thisDef, member: typeID)),
    ),
  });

  static Object mk({
    required ID id,
    required Object type,
    required String name,
    Object? value,
  }) =>
      Dict({IDID: id, typeID: type, nameID: name, valueID: value ?? Option.mk(type)});

  static ID id(Object binding) => (binding as Dict)[IDID].unwrap! as ID;
  static Object type(Object binding) => (binding as Dict)[typeID].unwrap!;
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
  Object getBinding(ID id) => (get<BindingCtx>() ?? const BindingCtx()).bindings[id].unwrap!;
  Iterable<Object> get getBindings => (get<BindingCtx>() ?? const BindingCtx()).bindings.values;
}

final coreCtx = Ctx.empty.withElement(TypeCtx(
  types: Dict({
    Type.id(ID.type): ID.def,
    Type.id(Type.type): Type.def,
    Type.id(TypeDef.type): TypeDef.def,
    Type.id(TypeTree.type): TypeTree.def,
    Type.id(UnionTag.type): UnionTag.def,
    Type.id(InterfaceDef.type): InterfaceDef.def,
    Type.id(ImplDef.type(ID())): ImplDef.def,
    Type.id(Impl.type(ID())): Impl.def,
    Type.id(Expr.type): Expr.def,
    Type.id(List.type(any)): List.def,
    Type.id(Map.type(any, any)): Map.def,
    Type.id(Construct.type): Construct.dataDef,
    Type.id(Option.type(any)): Option.def,
    Type.id(ID.type): ID.def,
    Type.id(number): numberDef,
    Type.id(text): textDef,
    Type.id(TypeDef.asType(Fn.dataDef)): Fn.dataDef,
  }),
  interfaces: Dict({
    Expr.interfaceID: Expr.interfaceDef,
    TypeProperty.interfaceID: TypeProperty.interfaceDef,
  }),
  impls: Dict({
    // exprs
    Impl.id(Var.exprImpl): Var.exprImplDef,
    Impl.id(Literal.exprImpl): Literal.exprImplDef,
    Impl.id(InterfaceAccess.exprImpl): InterfaceAccess.exprImplDef,
    Impl.id(Construct.impl): Construct.implDef,
    Impl.id(RecordAccess.exprImpl): RecordAccess.exprImplDef,
    Impl.id(Fn.exprImpl): Fn.exprImplDef,
    Impl.id(FnApp.exprImpl): FnApp.exprImplDef,
    Impl.id(ThisDef.exprImpl): ThisDef.exprImplDef,
    Impl.id(Placeholder.exprImpl): Placeholder.exprImplDef,
    // type properties
    Impl.id(MemberHas.impl): MemberHas.propImplDef,
  }),
));

Object eval(Ctx ctx, Object expr) {
  final data = Expr.data(expr);
  final implDef = (ctx.getImpl(Impl.id(Expr.impl(expr))) as Dict)[ImplDef.membersID].unwrap!;
  final dataType = Expr.dataType(implDef);
  final evalExprFn = Expr.evalExpr(implDef);
  return Fn.bodyCases(
    evalExprFn,
    pal: (bodyExpr) {
      return eval(
        ctx.withBinding(Binding.mk(
          id: Fn.argID(evalExprFn),
          type: dataType,
          name: Fn.argName(evalExprFn),
          value: Optional(data),
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
    TypeDef.mkDef(TypeDef.def),
    ImplDef.mkDef(TypeDef.moduleDefImpl),
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
    ImplDef.mkDef(InterfaceDef.moduleDefImpl),
    TypeDef.mkDef(ImplDef.def),
    ImplDef.mkDef(ImplDef.moduleDefImpl),
    TypeDef.mkDef(Impl.def),
    TypeDef.mkDef(Option.def),
    TypeDef.mkDef(Expr.def),
    InterfaceDef.mkDef(Expr.interfaceDef),
    TypeDef.mkDef(List.def),
    ImplDef.mkDef(List.mkExprImpl),
    TypeDef.mkDef(Map.def),
    ImplDef.mkDef(Map.mkExprImpl),
    TypeDef.mkDef(anyDef),
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
