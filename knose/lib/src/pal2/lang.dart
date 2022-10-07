import 'dart:convert';
import 'dart:core' as dart;
import 'dart:core';
import 'package:ctx/ctx.dart';
import 'package:reified_lenses/reified_lenses.dart' as reified;
import 'package:uuid/uuid.dart';
// ignore: unused_import
import 'package:knose/src/pal2/print.dart';

typedef FnMap = dart.Map<ID, Object Function(Ctx, Object)>;
typedef Dict = reified.Dict<Object, Object>;
typedef DartList = dart.List<Object>;
typedef Vec = reified.Vec<Object>;
typedef Set = reified.CSet<Object>;

class ID implements Comparable<ID> {
  static final typeDefID = ID('ID');
  static final def = TypeDef.unit('ID', id: typeDefID);
  static final type = Type.mk(typeDefID);

  static const _uuid = Uuid();

  final String id;
  final ID? tail;
  final String? label;

  ID([this.label])
      : id = _uuid.v4(),
        tail = null;

  const ID.from({
    required this.id,
    this.label,
    this.tail,
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

  ID append(ID other) =>
      ID.from(id: id, label: label, tail: tail == null ? other : tail!.append(other));

  bool isPrefixOf(ID other) {
    if (this.id != other.id) return false;
    if (this.tail == null) return true;
    if (other.tail == null) return false;
    return this.tail!.isPrefixOf(other.tail!);
  }
}

abstract class Module {
  static final IDID = ID('ID');
  static final nameID = ID('name');
  static final definitionsID = ID('definitions');

  static final def = TypeDef.record('Module', {
    IDID: TypeTree.mk('id', Type.lit(ID.type)),
    nameID: TypeTree.mk('name', Type.lit(text)),
    definitionsID: TypeTree.mk('definitions', Type.lit(List.type(ModuleDef.type))),
  });
  static final type = TypeDef.asType(def);

  static Object mk({ID? id, required String name, required DartList definitions}) =>
      Dict({IDID: id ?? ID(), nameID: name, definitionsID: List.mk(definitions)});

  static Object load(Ctx ctx, Object module) {
    Iterable<Object> expandDef(Object moduleDef) {
      final list = eval(
        ctx,
        FnApp.mk(
          RecordAccess.mk(
            RecordAccess.mk(Literal.mk(ModuleDef.type, moduleDef), ModuleDef.implID),
            ModuleDef.bindingsID,
          ),
          RecordAccess.mk(Literal.mk(ModuleDef.type, moduleDef), ModuleDef.dataID),
        ),
      );
      return List.iterate(list).expand(
        (union) => Union.cases(union, {
          ModuleDef.type: expandDef,
          Binding.type: (binding) => [binding],
        }),
      );
    }

    final bindings = List.iterate((module as Dict)[definitionsID].unwrap!).expand(expandDef);
    ctx = bindings.fold<Ctx>(ctx, (ctx, binding) => ctx.withBinding(binding));
    // try {
    for (final binding in bindings) {
      Binding.valueType(ctx, binding);
    }
    // } on MyException {
    //   return Option.mk();
    // }
    return Option.mk(ctx);
  }

  static final bindingOrType = Union.type([ModuleDef.type, Binding.type]);
}

abstract class ModuleDef extends InterfaceDef {
  static final dataTypeID = ID('dataType');
  static final bindingsID = ID('bindings');
  static final bindingsArgID = ID('bindingsArg');
  static final interfaceDef = InterfaceDef.record('ModuleDef', {
    dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
    bindingsID: TypeTree.mk(
      'bindings',
      Fn.typeExpr(
        argID: bindingsArgID,
        argType: Var.mk(dataTypeID),
        returnType: Type.lit(List.type(Module.bindingOrType)),
      ),
    ),
  });

  static Object mkImpl({
    required Object dataType,
    required Object bindings,
    ID? id,
  }) =>
      ImplDef.mk(
        id: id,
        implemented: InterfaceDef.id(interfaceDef),
        definition: Dict({
          dataTypeID: Type.lit(dataType),
          bindingsID: bindings,
        }),
      );

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final typeDefID = ID('ModuleDef');
  static final typeDef = TypeDef.record(
    'ModuleDef',
    {
      implID: TypeTree.mk('impl', Type.lit(InterfaceDef.implType(interfaceDef))),
      dataID: TypeTree.mk(
        'data',
        RecordAccess.mk(Var.mk(implID), dataTypeID),
      ),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static Object mk({required Object implDef, required Object data}) => Dict({
        implID: ImplDef.asImpl(Ctx.empty.withFnMap(coreFnMap), ModuleDef.interfaceDef, implDef),
        dataID: data
      });

  static Object impl(Object moduleDef) => (moduleDef as Dict)[implID].unwrap!;
  static Object dataType(Object moduleDef) => (impl(moduleDef) as Dict)[dataTypeID].unwrap!;
}

abstract class ValueDef {
  static final IDID = ID('ID');
  static final nameID = ID('name');
  static final expectedTypeID = ID('expectedType');
  static final valueID = ID('value');

  static final typeDef = TypeDef.record('ValueDef', {
    IDID: TypeTree.mk('id', Type.lit(ID.type)),
    nameID: TypeTree.mk('name', Type.lit(text)),
    expectedTypeID: TypeTree.mk('expectedType', Type.lit(Option.type(Type.type))),
    valueID: TypeTree.mk('value', Type.lit(Expr.type)),
  });
  static final type = TypeDef.asType(typeDef);

  static Object mk({
    required ID id,
    required String name,
    Object? expectedType,
    required Object value,
  }) =>
      ModuleDef.mk(
        implDef: moduleDefImplDef,
        data: Dict({
          IDID: id,
          nameID: name,
          expectedTypeID: Option.mk(expectedType),
          valueID: value,
        }),
      );

  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: TypeDef.asType(typeDef),
    bindings: FnExpr.dart(
      argID: ModuleDef.bindingsArgID,
      argName: 'valueDef',
      argType: Type.lit(TypeDef.asType(typeDef)),
      returnType: Type.lit(List.type(Module.bindingOrType)),
      body: const ID.from(id: '4a5ff699-216d-49c3-8fea-7687cb90a35b'),
    ),
    id: ID('ValueDefImpl'),
  );
}

abstract class TypeDef {
  static final IDID = ID('ID');
  static final comptimeID = ID('comptime');
  static final treeID = ID('tree');

  static Object record(
    String name,
    dart.Map<ID, Object> members, {
    ID? id,
    DartList comptime = const [],
  }) =>
      mk(TypeTree.record(name, members), id: id, comptime: comptime);
  static Object union(
    String name,
    dart.Map<ID, Dict> cases, {
    ID? id,
    DartList comptime = const [],
  }) =>
      mk(TypeTree.union(name, cases), id: id, comptime: comptime);
  static Object unit(String name, {ID? id}) => mk(TypeTree.unit(name), id: id);

  static Object mk(Object tree, {ID? id, DartList comptime = const []}) =>
      Dict({IDID: id ?? ID(TypeTree.name(tree)), comptimeID: List.mk(comptime), treeID: tree});

  static Object asType(Object typeDef, {DartList properties = const []}) => Type.mk(
        (typeDef as Dict)[IDID].unwrap! as ID,
        properties: properties,
      );

  static ID id(Object typeDef) => (typeDef as Dict)[IDID].unwrap! as ID;
  static Iterable<Object> comptime(Object typeDef) =>
      List.iterate((typeDef as Dict)[comptimeID].unwrap!);
  static Object tree(Object typeDef) => (typeDef as Dict)[treeID].unwrap!;

  static final def = TypeDef.record('TypeDef', {
    IDID: TypeTree.mk('id', Type.lit(ID.type)),
    comptimeID: TypeTree.mk('comptime', Type.lit(List.type(ID.type))),
    treeID: TypeTree.mk('tree', Type.lit(TypeTree.type)),
  });
  static final type = asType(def);

  static final _typeLitID = ID('TypeLiteral');
  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: type,
    bindings: FnExpr.dart(
      argID: ModuleDef.bindingsArgID,
      argName: 'typeDef',
      argType: Type.lit(type),
      returnType: Type.lit(List.type(Module.bindingOrType)),
      body: const ID.from(id: '01415159-a7a9-42ce-a749-0c6428775166'),
    ),
    id: ID('TypeDefImpl'),
  );

  static Object mkDef(Object def) => ModuleDef.mk(implDef: moduleDefImplDef, data: def);
}

abstract class Type {
  static final IDID = ID('ID');
  static final pathID = ID('path');
  static final propertiesID = ID('properties');

  static final _typeID = ID('Type');
  static final def = TypeDef.record(
    'Type',
    {
      IDID: TypeTree.mk('id', Type.lit(ID.type)),
      pathID: TypeTree.mk('path', Type.lit(List.type(ID.type))),
      propertiesID: TypeTree.mk('properties', Type.lit(List.type(TypeProperty.type))),
    },
    id: _typeID,
  );
  static final type = Type.mk(_typeID);

  static Object lit(Object type) => Literal.mk(Type.type, type);

  static Object mk(
    ID id, {
    DartList path = const [],
    DartList properties = const [],
  }) =>
      Dict({
        IDID: id,
        pathID: List.mk(path),
        propertiesID: List.mk(properties),
      });

  static Object mkExpr(
    ID id, {
    Object? path,
    DartList properties = const [],
  }) =>
      Construct.mk(
        Type.type,
        Dict({
          IDID: Literal.mk(ID.type, id),
          pathID: path ?? Literal.mk(List.type(ID.type), List.mk(const [])),
          propertiesID: List.mkExpr(TypeProperty.type, properties),
        }),
      );

  static ID id(Object type) => (type as Dict)[IDID].unwrap! as ID;
  static Object path(Object type) => (type as Dict)[pathID].unwrap!;
  static Object properties(Object type) => (type as Dict)[propertiesID].unwrap!;
  static Object memberEquals(Object type, dart.List<ID> path) {
    return List.iterate(properties(type)).expand<Object>((property) {
      if (TypeProperty.dataType(property) != MemberHas.type) return [];
      final memberHas = TypeProperty.data(property);
      if (MemberHas.path(memberHas) != List.mk(path)) return [];
      final memberHasProp = MemberHas.property(memberHas);
      if (TypeProperty.dataType(memberHasProp) != Equals.type) return [];
      return [Equals.equalTo(TypeProperty.data(memberHasProp))];
    }).first;
  }

  static Iterable<Object> exprIterateProperties(Ctx ctx, Object typeExpr) {
    final properties = reduce(ctx, RecordAccess.mk(typeExpr, Type.propertiesID));
    if (Expr.dataType(properties) == Literal.type) {
      return List.iterate(Literal.getValue(Expr.data(properties)))
          .map((e) => Literal.mk(TypeProperty.type, e));
    } else if (Expr.dataType(properties) == Type.mk(List.mkExprTypeDefID)) {
      return List.iterate(List.mkExprValues(Expr.data(properties)));
    } else {
      throw UnimplementedError(
        "Type.exprIterateProperties on non literal or construct: ${Type.id(Expr.dataType(typeExpr))}",
      );
    }
  }

  static Object exprMemberEquals(Ctx ctx, Object typeExpr, dart.List<ID> path) {
    return exprIterateProperties(ctx, typeExpr).expand<Object>((property) {
      if (TypeProperty.exprDataType(ctx, property) != MemberHas.type) {
        return [];
      }
      final memberHas = reduce(ctx, RecordAccess.mk(property, TypeProperty.dataID));
      if (reduce(ctx, RecordAccess.mk(memberHas, MemberHas.pathID)) !=
          Literal.mk(List.type(ID.type), List.mk(path))) return [];
      final memberHasProp = reduce(ctx, RecordAccess.mk(memberHas, MemberHas.propertyID));
      if (TypeProperty.exprDataType(ctx, memberHasProp) != Equals.type) {
        return [];
      }
      return [
        reduce(
          ctx,
          RecordAccess.mk(RecordAccess.mk(memberHasProp, TypeProperty.dataID), Equals.equalToID),
        )
      ];
    }).first;
  }

  static Object withProperty(Object type, Object property) {
    return Type.mk(
      Type.id(type),
      path: [...List.iterate(Type.path(type))],
      properties: [...List.iterate(Type.properties(type)), property],
    );
  }
}

abstract class TypeProperty {
  static final dataTypeID = ID('dataType');
  static final interfaceID = ID('TypeProperty');
  static final interfaceDef = InterfaceDef.record(
    'TypePropertyImpl',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
    },
    id: interfaceID,
  );
  static final implType = InterfaceDef.implType(interfaceDef);

  static Object mkImpl({
    required ID id,
    required Object dataType,
  }) =>
      ImplDef.mk(
        id: id,
        implemented: interfaceID,
        definition: Dict({dataTypeID: Type.lit(dataType)}),
      );

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final typeDef = TypeDef.record('TypeProperty', {
    implID: TypeTree.mk('impl', Type.lit(implType)),
    dataID: TypeTree.mk(
      'data',
      RecordAccess.mk(Var.mk(implID), dataTypeID),
    ),
  });
  static final type = TypeDef.asType(typeDef);

  static Dict mk(Object impl, Object data) => Dict({implID: impl, dataID: data});

  static Object mkExpr(Object implDef, Object data) => Construct.mk(
        type,
        Dict({implID: FnApp.mk(Var.mk(ImplDef.bindingID(implDef)), unitExpr), dataID: data}),
      );

  static Object impl(Object typeProperty) => (typeProperty as Dict)[implID].unwrap!;
  static Object data(Object typeProperty) => (typeProperty as Dict)[dataID].unwrap!;
  static Object dataType(Object typeProperty) => (impl(typeProperty) as Dict)[dataTypeID].unwrap!;
  static Object exprDataType(Ctx ctx, Object typeProperty) => Literal.getValue(Expr.data(reduce(
        ctx,
        RecordAccess.mk(
          RecordAccess.mk(typeProperty, TypeProperty.implID),
          TypeProperty.dataTypeID,
        ),
      )));
}

abstract class Equals extends TypeProperty {
  static final dataTypeID = ID('dataType');
  static final equalToID = ID('equalTo');

  static final typeDefID = ID('Equals');
  static final typeDef = TypeDef.record(
    'Equals',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      equalToID: TypeTree.mk('equalTo', Var.mk(dataTypeID)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final propImplDef = TypeProperty.mkImpl(id: ID('EqualsTypePropertyImpl'), dataType: type);
  static final impl = Dict({TypeProperty.dataTypeID: type});

  static Dict mk(Object dataType, Object equalTo) =>
      TypeProperty.mk(impl, Dict({dataTypeID: dataType, equalToID: equalTo}));

  static Object mkExpr(Object dataType, Object equalTo) => TypeProperty.mkExpr(
        propImplDef,
        Construct.mk(
          type,
          Dict({
            dataTypeID: dataType,
            equalToID: equalTo,
          }),
        ),
      );

  static Object dataType(Object equals) => (equals as Dict)[dataTypeID].unwrap!;
  static Object equalTo(Object equals) => (equals as Dict)[equalToID].unwrap!;
}

abstract class MemberHas extends TypeProperty {
  static final pathID = ID('path');
  static final propertyID = ID('property');

  static final typeDefID = ID('MemberHas');
  static final typeDef = TypeDef.record(
    'MemberHas',
    {
      pathID: TypeTree.mk('path', Type.lit(List.type(ID.type))),
      propertyID: TypeTree.mk('property', Type.lit(TypeProperty.type)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final propImplDef = TypeProperty.mkImpl(
    id: ID('MemberHasTypePropertyImpl'),
    dataType: type,
  );
  static final propImpl = Dict({TypeProperty.dataTypeID: type});

  static Object mk({required DartList path, required Object property}) => TypeProperty.mk(
        propImpl,
        Dict({pathID: List.mk(path), propertyID: property}),
      );

  static Object mkExpr({required Object path, required Object property}) => TypeProperty.mkExpr(
        propImplDef,
        Construct.mk(TypeDef.asType(typeDef), Dict({pathID: path, propertyID: property})),
      );

  static Object mkEquals(DartList path, Object type, Object equalTo) =>
      mk(path: path, property: Equals.mk(type, equalTo));

  static Object mkEqualsExpr(DartList path, Object type, Object equalTo) => mkExpr(
        path: Literal.mk(List.type(ID.type), List.mk(path)),
        property: Equals.mkExpr(type, equalTo),
      );

  static Dict eachEquals(Object type) => Dict({
        for (final prop in List.iterate(Type.properties(type)))
          if (TypeProperty.dataType(prop) == MemberHas.type)
            for (final memberHas in [TypeProperty.data(prop)])
              for (final memberProp in [MemberHas.property(memberHas)])
                if (TypeProperty.dataType(memberProp) == Equals.type)
                  MemberHas.path(memberHas): TypeProperty.data(memberProp)
      });

  static Object path(Object memberHas) => (memberHas as Dict)[pathID].unwrap!;
  static Object property(Object memberHas) => (memberHas as Dict)[propertyID].unwrap!;
}

abstract class UnionTag {
  static final tagID = ID('tag');
  static final valueID = ID('value');

  static final def = TypeDef.record('UnionTag', {
    tagID: TypeTree.mk('tag', Type.lit(ID.type)),
    valueID: TypeTree.mk('value', Type.lit(Any.type)),
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
      nameID: TypeTree.mk('name', Type.lit(text)),
      treeID: TypeTree.union('tree', {
        recordID: TypeTree.mk('record', Type.lit(Map.type(ID.type, TypeTree.type))),
        unionID: TypeTree.mk('union', Type.lit(Map.type(ID.type, TypeTree.type))),
        leafID: TypeTree.mk('leaf', Type.lit(Expr.type))
      }),
    },
    id: id,
  );
  static final type = Type.mk(id);

  static Dict record(String name, dart.Map<ID, Object> members) =>
      Dict({nameID: name, treeID: UnionTag.mk(recordID, Map.mk(members))});
  static Dict union(String name, dart.Map<ID, Dict> cases) =>
      Dict({nameID: name, treeID: UnionTag.mk(unionID, Map.mk(cases))});
  static Dict mk(String name, Object type) =>
      Dict({nameID: name, treeID: UnionTag.mk(leafID, type)});
  static Dict unit(String name) => TypeTree.record(name, const {});

  static String name(Object typeTree) => (typeTree as Dict)[nameID].unwrap! as String;
  static Object tree(Object typeTree) => (typeTree as Dict)[treeID].unwrap!;

  static T treeCases<T>(
    Object typeTree, {
    required T Function(Dict) record,
    required T Function(Dict) union,
    required T Function(Object) leaf,
  }) {
    final tree = TypeTree.tree(typeTree);
    final tag = UnionTag.tag(tree);
    final value = UnionTag.value(tree);
    if (tag == recordID) {
      return record(Map.entries(value));
    } else if (tag == unionID) {
      return union(Map.entries(value));
    } else if (tag == leafID) {
      return leaf(value);
    } else {
      throw Exception("unknown tree case");
    }
  }

  static Object treeAt(Object typeTree, Iterable<Object> path) {
    if (path.isEmpty) {
      return typeTree;
    } else {
      return treeCases(
        typeTree,
        record: (record) => treeAt(record[path.first].unwrap!, path.skip(1)),
        union: (union) => treeAt(union[path.first].unwrap!, path.skip(1)),
        leaf: (leaf) => throw Exception('tried to look up type tree at unknown location'),
      );
    }
  }

  static Object augmentTree(Object type, Object dataTree) {
    Object augmentImpl(Dict dataTree, Iterable<Object> path, Object value) {
      if (path.length == 1) {
        return dataTree.put(path.single, value);
      } else {
        return dataTree.put(
          path.first,
          augmentImpl(dataTree[path.first].unwrap! as Dict, path.skip(1), value),
        );
      }
    }

    return MemberHas.eachEquals(type).entries.fold(
          dataTree,
          (dataTree, entry) =>
              augmentImpl(dataTree as Dict, List.iterate(entry.key), Equals.equalTo(entry.value)),
        );
  }

  static Iterable<Object> dataBindings(Object typeTree, Object dataTree) {
    return foldData(
      [],
      typeTree,
      dataTree,
      (prev, typeLeaf, dataLeaf, path) => [
        ...prev,
        Binding.mkLazy(
          id: path.last as ID,
          name: (path.last as ID).label ?? '${path.last}',
          type: (ctx) => eval(ctx, typeLeaf),
          value: (ctx) => dataLeaf,
        ),
      ],
    );
  }

  static Object mapData(
    Object typeTree,
    Object dataTree,
    Object Function(Object, Object, DartList path) leafFn, {
    DartList path = const [],
  }) {
    return treeCases(
      typeTree,
      record: (record) => record.mapValues(
        (k, v) => mapData(v, (dataTree as Dict)[k].unwrap!, leafFn, path: [...path, k]),
      ),
      union: (union) => UnionTag.mk(
        UnionTag.tag(dataTree),
        mapData(
          union[UnionTag.tag(dataTree)].unwrap!,
          UnionTag.value(dataTree),
          leafFn,
          path: [...path, UnionTag.tag(dataTree)],
        ),
      ),
      leaf: (leaf) => leafFn(leaf, dataTree, path),
    );
  }

  static Object maybeMapData(
    Object typeTree,
    Object dataTree,
    Object Function(Object, Object, DartList path) leafFn,
  ) {
    Object recurse(Object typeTree, Object dataTree, DartList path) {
      return treeCases(
        typeTree,
        record: (record) => Option.mk(Dict(dart.Map.fromEntries(record.entries.expand(
          (e) => Option.cases(
            recurse(
              e.value,
              (dataTree as Dict)[e.key].unwrap!,
              [...path, e.key],
            ),
            some: (subTree) => [MapEntry(e.key, subTree)],
            none: () => const [],
          ),
        )))),
        union: (union) => Option.mk(UnionTag.mk(
          UnionTag.tag(dataTree),
          Option.unwrap(recurse(
            union[UnionTag.tag(dataTree)].unwrap!,
            UnionTag.value(dataTree),
            [...path, UnionTag.tag(dataTree)],
          )),
        )),
        leaf: (leaf) => leafFn(leaf, dataTree, path),
      );
    }

    return Option.unwrap(recurse(typeTree, dataTree, const []));
  }

  static T foldData<T>(
    T initialValue,
    Object typeTree,
    Object dataTree,
    T Function(T, Object, Object, DartList path) foldFn, {
    DartList path = const [],
  }) {
    return treeCases(
      typeTree,
      record: (record) => record.entries.fold(
        initialValue,
        (prev, e) => foldData(
          prev,
          e.value,
          (dataTree as Dict)[e.key].unwrap!,
          foldFn,
          path: [...path, e.key],
        ),
      ),
      union: (union) => foldData(
        initialValue,
        union[UnionTag.tag(dataTree)].unwrap!,
        UnionTag.value(dataTree),
        foldFn,
        path: [...path, UnionTag.tag(dataTree)],
      ),
      leaf: (leaf) => foldFn(initialValue, leaf, dataTree, path),
    );
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
    IDID: TypeTree.mk('id', Type.lit(ID.type)),
    treeID: TypeTree.mk('tree', Type.lit(TypeTree.type)),
  });
  static final type = TypeDef.asType(def);

  static Dict mk(Dict tree, {ID? id}) => Dict({IDID: id ?? ID(TypeTree.name(tree)), treeID: tree});
  static Object record(String name, dart.Map<ID, Dict> members, {ID? id}) =>
      InterfaceDef.mk(TypeTree.record(name, members), id: id);
  static Dict union(String name, dart.Map<ID, Dict> cases, {ID? id}) =>
      InterfaceDef.mk(TypeTree.union(name, cases), id: id);

  static ID id(Object ifaceDef) => (ifaceDef as Dict)[IDID].unwrap! as ID;
  static Object tree(Object ifaceDef) => (ifaceDef as Dict)[treeID].unwrap!;

  static final _innerTypeDefID = ID('typeDef');
  static ID innerTypeDefID(ID id) => id.append(_innerTypeDefID);
  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: type,
    bindings: FnExpr.dart(
      argID: ModuleDef.bindingsArgID,
      argName: 'interfaceDef',
      argType: Type.lit(type),
      returnType: Type.lit(List.type(Module.bindingOrType)),
      body: const ID.from(id: '524fbec2-aa08-43bd-b8b3-ffe89d89d7aa'),
    ),
    id: ID('InterfaceDefImpl'),
  );

  static Object mkDef(Object def) => ModuleDef.mk(implDef: moduleDefImplDef, data: def);
  static Object implType(Object interfaceDef, [DartList properties = const []]) =>
      implTypeByID(InterfaceDef.id(interfaceDef), properties);
  static Object implTypeByID(ID interfaceID, [DartList properties = const []]) =>
      Type.mk(innerTypeDefID(interfaceID), properties: properties);
  static Object implTypeExpr(Object interfaceDef, [DartList properties = const []]) =>
      implTypeExprByID(InterfaceDef.id(interfaceDef), properties);
  static Object implTypeExprByID(ID interfaceID, [DartList properties = const []]) =>
      Type.mkExpr(innerTypeDefID(interfaceID), properties: properties);
}

abstract class ImplDef {
  static final IDID = ID('ID');
  static final implementedID = ID('implemented');
  static final definitionID = ID('definition');
  static final definitionArgID = ID('definitionArg');

  static final def = TypeDef.record('ImplDef', {
    IDID: TypeTree.mk('id', Type.lit(ID.type)),
    implementedID: TypeTree.mk('implemented', Type.lit(ID.type)),
    definitionID: TypeTree.mk('definition', Type.lit(Expr.type)),
  });
  static final type = TypeDef.asType(def);

  static Object mk({ID? id, required ID implemented, required Object definition}) =>
      mkParameterized(
        id: id,
        implemented: implemented,
        argType: unit,
        definition: (_) => definition,
      );

  static Dict mkParameterized({
    ID? id,
    required ID implemented,
    required Object argType,
    required Object Function(Object) definition,
  }) =>
      Dict({
        IDID: id ?? ID(),
        implementedID: implemented,
        definitionID: FnExpr.palInferred(
          argID: definitionArgID,
          argName: 'definitionArg',
          argType: Type.lit(argType),
          body: Construct.mk(
            InterfaceDef.implTypeByID(implemented),
            definition(Var.mk(definitionArgID)),
          ),
        ),
      });

  static Object definition(Object implDef) => (implDef as Dict)[definitionID].unwrap!;

  static final _bindingIDPrefixID = ID('ImplDefBindingIDPrefix');
  static ID bindingIDPrefixForID(ID interfaceID) => _bindingIDPrefixID.append(interfaceID);
  static ID bindingIDPrefix(Object implDef) => bindingIDPrefixForID(ImplDef.implemented(implDef));
  static ID bindingID(Object implDef) => bindingIDPrefix(implDef).append(ImplDef.id(implDef));
  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: type,
    bindings: FnExpr.dart(
      argID: ModuleDef.bindingsArgID,
      argName: 'typeDef',
      argType: Type.lit(type),
      returnType: Type.lit(List.type(Module.bindingOrType)),
      body: const ID.from(id: '85c45fc9-c594-43b9-b126-739713a1c5e8'),
    ),
    id: ID('ImplDefImpl'),
  );

  static Object mkDef(Object def) => ModuleDef.mk(implDef: moduleDefImplDef, data: def);

  static Object asImpl(Ctx ctx, Object interfaceDef, Object implDef) {
    return TypeTree.mapData(
      InterfaceDef.tree(interfaceDef),
      Construct.tree(Expr.data(FnExpr.bodyCases(
        Expr.data(ImplDef.definition(implDef)),
        dart: (_) => throw Exception(),
        pal: (_) => _,
      ))),
      (_, dataLeaf, __) => eval(ctx, dataLeaf),
    );
  }

  static ID id(Object impl) => (impl as Dict)[IDID].unwrap! as ID;
  static ID implemented(Object impl) => (impl as Dict)[implementedID].unwrap! as ID;
}

abstract class Union {
  static final possibleTypesID = ID('dataType');
  static final thisTypeID = ID('thisType');
  static final valueID = ID('value');

  static final def = TypeDef.record('Union', {
    possibleTypesID: TypeTree.mk('possibleTypes', Type.lit(List.type(Type.type))),
    thisTypeID: TypeTree.mk('thisType', Type.lit(Type.type)),
    valueID: TypeTree.mk('value', Var.mk(thisTypeID)),
  });

  static Object mk(Object thisType, Object value) => Dict({
        thisTypeID: thisType,
        valueID: value,
      });

  static Object type(DartList possibleTypes) => TypeDef.asType(def, properties: [
        MemberHas.mk(
          path: [possibleTypesID],
          property: Equals.mk(List.type(Type.type), List.mk(possibleTypes)),
        )
      ]);

  static T cases<T>(Object union, dart.Map<Object, T Function(Object)> types) {
    return types[(union as Dict)[thisTypeID].unwrap!]!(union[valueID].unwrap!);
  }
}

abstract class Pair {
  static final firstTypeID = ID('firstType');
  static final secondTypeID = ID('secondType');
  static final firstID = ID('first');
  static final secondID = ID('second');
  static final def = TypeDef.record('Pair', {
    firstTypeID: TypeTree.mk('firstType', Type.lit(Type.type)),
    secondTypeID: TypeTree.mk('secondType', Type.lit(Type.type)),
    firstID: TypeTree.mk('first', Var.mk(firstTypeID)),
    secondID: TypeTree.mk('second', Var.mk(secondTypeID)),
  }, comptime: [
    firstTypeID,
    secondTypeID
  ]);

  static Object type(Object first, Object second) => TypeDef.asType(def, properties: [
        MemberHas.mkEquals([firstTypeID], Type.type, first),
        MemberHas.mkEquals([secondTypeID], Type.type, second),
      ]);

  static Object typeExpr(Object first, Object second) => Type.mkExpr(TypeDef.id(def), properties: [
        MemberHas.mkEqualsExpr([firstTypeID], Type.lit(Type.type), first),
        MemberHas.mkEqualsExpr([secondTypeID], Type.lit(Type.type), second),
      ]);

  static Object first(Object pair) => (pair as Dict)[firstID].unwrap!;
  static Object second(Object pair) => (pair as Dict)[secondID].unwrap!;
  static Object mk(Object first, Object second) => Dict({firstID: first, secondID: second});
  static Object mkExpr(Object firstType, Object secondType, Object first, Object second) =>
      Construct.mk(
        TypeDef.asType(def),
        Dict({
          firstTypeID: firstType,
          secondTypeID: secondType,
          firstID: first,
          secondID: second,
        }),
      );
}

abstract class Option {
  static final dataTypeID = ID('dataType');
  static final valueID = ID('value');
  static final someID = ID('some');
  static final noneID = ID('none');

  static final typeDefID = ID('Option');
  static final def = TypeDef.record(
    'Option',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      valueID: TypeTree.union('value', {
        someID: TypeTree.mk('some', Var.mk(dataTypeID)),
        noneID: TypeTree.unit('none'),
      }),
    },
    id: typeDefID,
    comptime: [dataTypeID],
  );

  static Object type(Object dataType) => Type.mk(typeDefID, properties: [
        MemberHas.mk(path: [dataTypeID], property: Equals.mk(Type.type, dataType)),
      ]);

  static Object typeExpr(Object dataType) => Type.mkExpr(Type.id(type(unit)), properties: [
        MemberHas.mkEqualsExpr([dataTypeID], Type.lit(Type.type), dataType),
      ]);

  static T cases<T>(
    Object option, {
    required T Function(Object) some,
    required T Function() none,
  }) {
    final value = (option as Dict)[valueID].unwrap!;
    return UnionTag.tag(value) == someID ? some(UnionTag.value(value)) : none();
  }

  static Object map(Object option, Object Function(Object) f) =>
      cases(option, some: f, none: () => Option.mk());

  static Object unwrap(Object option) =>
      Option.cases(option, some: (v) => v, none: () => throw Exception());

  static bool isPresent(Object option) =>
      Option.cases(option, some: (_) => true, none: () => false);

  static final _noneUnionTag = UnionTag.mk(noneID, const Dict());
  static Object mk([Object? value]) => Dict({
        valueID: value == null ? _noneUnionTag : UnionTag.mk(someID, value),
      });

  static Object someExpr(Object dataType, Object value) => Construct.mk(
        Option.type(dataType),
        Dict({
          dataTypeID: Type.lit(dataType),
          valueID: UnionTag.mk(someID, value),
        }),
      );

  static Object noneExpr(Object dataType) => Construct.mk(
        Option.type(dataType),
        Dict({
          dataTypeID: Type.lit(dataType),
          valueID: UnionTag.mk(noneID, const Dict()),
        }),
      );
}

abstract class Expr {
  static final dataTypeID = ID('dataType');
  static final typeCheckID = ID('typeCheck');
  static final typeCheckArgID = ID('typeCheckArg');
  static final reduceID = ID('reduce');
  static final reduceArgID = ID('reduceArg');
  static final evalExprID = ID('evalExpr');
  static final evalExprArgID = ID('evalExprArg');

  static final interfaceID = ID('Expr');
  static final interfaceDef = InterfaceDef.record(
    'ExprInterface',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      typeCheckID: TypeTree.mk(
        'typeCheck',
        Fn.typeExpr(
          argID: typeCheckArgID,
          argType: Var.mk(dataTypeID),
          returnType: Type.lit(Option.type(typeExprType)),
        ),
      ),
      reduceID: TypeTree.mk(
        'reduce',
        Fn.typeExpr(
          argID: reduceArgID,
          argType: Var.mk(dataTypeID),
          returnType: Type.lit(Expr.type),
        ),
      ),
      evalExprID: TypeTree.mk(
        'eval',
        Fn.typeExpr(
          argID: evalExprArgID,
          argType: Var.mk(dataTypeID),
          returnType: Type.lit(Any.type),
        ),
      )
    },
    id: interfaceID,
  );
  static final implType = InterfaceDef.implTypeByID(interfaceID);

  static Object mkImplDef({
    required Object dataType,
    required String argName,
    required ID typeCheckBody,
    required ID reduceBody,
    required ID evalBody,
    ID? id,
  }) =>
      ImplDef.mk(
        id: id ?? ID(),
        implemented: interfaceID,
        definition: Dict({
          dataTypeID: Type.lit(dataType),
          typeCheckID: FnExpr.dart(
            argType: Type.lit(dataType),
            returnType: Type.lit(Option.type(typeExprType)),
            argID: typeCheckArgID,
            argName: argName,
            body: typeCheckBody,
          ),
          reduceID: FnExpr.dart(
            argType: Type.lit(dataType),
            returnType: Type.lit(Expr.type),
            argID: reduceArgID,
            argName: argName,
            body: reduceBody,
          ),
          evalExprID: FnExpr.dart(
            argType: Type.lit(dataType),
            returnType: Type.lit(Any.type),
            argID: evalExprArgID,
            argName: argName,
            body: evalBody,
          ),
        }),
      );

  static Object mkImpl({
    required Object dataType,
    required String argName,
    required ID typeCheckBody,
    required ID reduceBody,
    required ID evalBody,
  }) =>
      Dict({
        dataTypeID: dataType,
        typeCheckID: Fn.mk(
          argID: typeCheckArgID,
          argName: argName,
          body: Fn.mkDartBody(typeCheckBody),
        ),
        reduceID: Fn.mk(
          argID: reduceArgID,
          argName: argName,
          body: Fn.mkDartBody(reduceBody),
        ),
        evalExprID: Fn.mk(
          argID: evalExprArgID,
          argName: argName,
          body: Fn.mkDartBody(evalBody),
        ),
      });

  static Object dataType(Object expr) => (impl(expr) as Dict)[dataTypeID].unwrap!;
  static Object evalExpr(Object expr) => (impl(expr) as Dict)[evalExprID].unwrap!;

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final _defID = ID('ExprData');
  static final def = TypeDef.record(
    'Expr',
    {
      implID: TypeTree.mk('impl', Type.lit(implType)),
      dataID: TypeTree.mk('data', RecordAccess.mk(Var.mk(implID), Expr.dataTypeID)),
    },
    id: _defID,
  );

  static final type = Type.mk(_defID);

  static Object mk({required Object data, required Object impl}) =>
      Dict({dataID: data, implID: impl});

  static Object mkExpr({required Object data, required Object impl}) =>
      Construct.mk(Expr.type, Dict({dataID: data, implID: impl}));

  static Object data(Object expr) => (expr as Dict)[dataID].unwrap!;
  static Object impl(Object expr) => (expr as Dict)[implID].unwrap!;

  static Object typeCheckFn = FnExpr.from(
    argName: 'expr',
    argType: Type.lit(Expr.type),
    returnType: (_) => Type.lit(Option.type(typeExprType)),
    body: (arg) => FnApp.mk(
      RecordAccess.mk(RecordAccess.mk(arg, implID), typeCheckID),
      RecordAccess.mk(arg, dataID),
    ),
  );

  static Object reduceFn = FnExpr.from(
    argName: 'expr',
    argType: Type.lit(Expr.type),
    returnType: (_) => Type.lit(Option.type(Expr.type)),
    body: (arg) => FnApp.mk(
      RecordAccess.mk(RecordAccess.mk(arg, implID), reduceID),
      RecordAccess.mk(arg, dataID),
    ),
  );
}

abstract class List {
  static final typeID = ID('type');
  static final itemsID = ID('items');
  static final typeDefID = ID('List');
  static final def = TypeDef.record(
    'List',
    {
      typeID: TypeTree.mk('type', Type.lit(Type.type)),
      itemsID: TypeTree.unit('items'),
    },
    id: typeDefID,
    comptime: [typeID],
  );

  static final mkExprTypeDefID = ID('mkExpr');
  static final mkTypeID = ID('mkType');
  static final mkValuesID = ID('mkValues');
  static final exprTypeDef = TypeDef.record(
    'MkList',
    {
      mkTypeID: TypeTree.mk('type', Type.lit(Type.type)),
      mkValuesID: TypeTree.mk('mkValues', Type.lit(List.type(Expr.type))),
    },
    id: mkExprTypeDefID,
  );
  static final mkExprType = Type.mk(mkExprTypeDefID);

  static const _typeFn = ID.from(id: '6c67f06e-cbe0-4a46-a7e4-c04ee77eb3e1');

  static const _reduceFn = ID.from(id: '6600af92-b24d-4e65-8b78-35d9ba9d8b12');

  static const _evalFn = ID.from(id: 'd755250f-c583-4d96-84da-f4c0a6bdd823');
  static final mkExprImplDef = Expr.mkImplDef(
    dataType: mkExprType,
    argName: 'mkListData',
    typeCheckBody: _typeFn,
    reduceBody: _reduceFn,
    evalBody: _evalFn,
  );
  static final mkExprImpl = Expr.mkImpl(
    dataType: mkExprType,
    argName: 'mkListData',
    typeCheckBody: _typeFn,
    reduceBody: _reduceFn,
    evalBody: _evalFn,
  );

  static Object type(Object type) => Type.mk(typeDefID, properties: [
        MemberHas.mk(path: [typeID], property: Equals.mk(Type.type, type)),
      ]);

  static Object typeExpr(Object type) => Type.mkExpr(typeDefID, properties: [
        MemberHas.mkEqualsExpr([typeID], Type.lit(Type.type), type),
      ]);

  static Object mk(DartList values) => Dict({itemsID: Vec(values)});

  static Object mkExpr(Object type, DartList values) => Expr.mk(
        impl: mkExprImpl,
        data: Dict({mkTypeID: type, mkValuesID: List.mk(values)}),
      );

  static Object mkExprDataType(Object listExpr) => (listExpr as Dict)[mkTypeID].unwrap!;
  static Object mkExprValues(Object listExpr) => (listExpr as Dict)[mkValuesID].unwrap!;
  static Vec _items(Object list) => (list as Dict)[itemsID].unwrap! as Vec;
  static Iterable<Object> iterate(Object list) => _items(list);
  static Object _withList(Object list, DartList Function(Iterable<Object>) f) =>
      List.mk(f(_items(list)));
  static Object add(Object list, Object item) => _withList(list, (i) => [...i, item]);
  static Object tail(Object list) => _withList(list, (i) => [...i.skip(1)]);
}

abstract class Map {
  static final keyID = ID('key');
  static final valueID = ID('value');
  static final entriesID = ID('entries');
  static final def = TypeDef.record(
    'Map',
    {
      keyID: TypeTree.mk('key', Type.lit(Type.type)),
      valueID: TypeTree.mk('value', Type.lit(Type.type)),
      entriesID: TypeTree.mk('entries', Type.lit(unit)),
    },
    comptime: [keyID, valueID],
  );

  static Object type(Object key, Object value) => TypeDef.asType(def, properties: [
        MemberHas.mkEquals([keyID], Type.type, key),
        MemberHas.mkEquals([valueID], Type.type, value),
      ]);
  static Object typeExpr(Object key, Object value) => Type.mkExpr(TypeDef.id(def), properties: [
        MemberHas.mkEqualsExpr([keyID], Type.lit(Type.type), key),
        MemberHas.mkEqualsExpr([valueID], Type.lit(Type.type), value),
      ]);

  static Object mk(dart.Map<Object, Object> values) => Dict({entriesID: Dict(values)});

  static final mkExprID = ID('mkExpr');
  static final mkKeyID = ID('mkKey');
  static final mkValueID = ID('mkValue');
  static final mkEntriesID = ID('mkValues');
  static final exprDataDef = TypeDef.record(
    'MkMap',
    {
      mkKeyID: TypeTree.mk('key', Type.lit(Type.type)),
      mkValueID: TypeTree.mk('value', Type.lit(Type.type)),
      mkEntriesID: TypeTree.mk('entries', Type.lit(List.type(List.type(Expr.type)))),
    },
    id: mkExprID,
  );
  static final mkType = Type.mk(mkExprID);

  static final mkExprImplDef = Expr.mkImplDef(
    dataType: mkType,
    argName: 'mkMapData',
    typeCheckBody: const ID.from(id: '7f2c7445-867b-4d44-afae-040ee700bff6'),
    reduceBody: const ID.from(id: '7fa732c0-a61d-4e43-94e4-c4fafe04d254'),
    evalBody: const ID.from(id: '19e1d36f-81f1-4c8e-bfc5-69cbde60bd8a'),
  );
  static Object mkExpr(Type key, Type value, Object entries) => Expr.mk(
        impl: ImplDef.asImpl(Ctx.empty.withFnMap(coreFnMap), Expr.interfaceDef, mkExprImplDef),
        data: Dict({mkKeyID: key, mkValueID: value, mkEntriesID: entries}),
      );

  static Dict entries(Object map) => (map as Dict)[entriesID].unwrap! as Dict;
}

abstract class Any {
  static final typeID = ID('type');
  static final valueID = ID('value');

  static final anyTypeID = ID('Any');
  static final def = TypeDef.record(
    'Any',
    {
      typeID: TypeTree.mk('type', Type.lit(Type.type)),
      valueID: TypeTree.mk('value', Var.mk(typeID)),
    },
    id: anyTypeID,
  );
  static final type = Type.mk(anyTypeID);

  static Object getType(Object any) => (any as Dict)[typeID].unwrap!;
  static Object getValue(Object any) => (any as Dict)[valueID].unwrap!;

  static Object mk(Object type, Object value) => Dict({typeID: type, valueID: value});
  static Object mkExpr(Object type, Object value) =>
      Construct.mk(Any.type, Dict({typeID: type, valueID: value}));
}

final textDef = TypeDef.unit('Text');
final text = TypeDef.asType(textDef);
final numberDef = TypeDef.unit('Number');
final number = TypeDef.asType(numberDef);
final booleanDef = TypeDef.unit('Boolean');
final boolean = TypeDef.asType(booleanDef);
final unitDef = TypeDef.unit('Unit');
final unit = TypeDef.asType(unitDef);
const unitValue = Dict();
final unitExpr = Literal.mk(unit, unitValue);
final bottomDef = TypeDef.mk(TypeTree.union('Bottom', const {}));
final bottom = TypeDef.asType(bottomDef);
final typeExprType = Expr.type;

abstract class Fn {
  static final argIDID = ID('argID');
  static final argNameID = ID('argName');
  static final argTypeID = ID('argType');
  static final returnTypeID = ID('returnType');
  static final bodyID = ID('body');
  static final palID = ID('pal');
  static final dartID = ID('dart');
  static final closureID = ID('closure');

  static final typeDefID = ID('Fn');
  static final typeDef = TypeDef.record(
    'Fn',
    {
      argIDID: TypeTree.mk('argID', Type.lit(ID.type)),
      argNameID: TypeTree.mk('argName', Type.lit(text)),
      argTypeID: TypeTree.mk('argType', Type.lit(Type.type)),
      returnTypeID: TypeTree.mk('returnType', Type.lit(typeExprType)),
      bodyID: TypeTree.union('body', {
        palID: TypeTree.mk('pal', Type.lit(Expr.type)),
        dartID: TypeTree.mk('dart', Type.lit(ID.type)),
      }),
      closureID: TypeTree.mk('closure', Type.lit(List.type(Binding.type))),
    },
    id: typeDefID,
  );

  static Object type({
    required ID argID,
    required Object argType,
    required Object returnType,
  }) =>
      Type.mk(typeDefID, properties: [
        MemberHas.mkEquals([argIDID], ID.type, argID),
        MemberHas.mkEquals([argTypeID], Type.type, argType),
        MemberHas.mkEquals([returnTypeID], typeExprType, returnType),
      ]);

  static Object typeExpr({
    required ID argID,
    required Object argType,
    required Object returnType,
  }) =>
      Type.mkExpr(typeDefID, properties: [
        Literal.mk(
          TypeProperty.type,
          MemberHas.mkEquals([argIDID], ID.type, argID),
        ),
        MemberHas.mkEqualsExpr([argTypeID], Type.lit(Type.type), argType),
        MemberHas.mkEqualsExpr(
          [returnTypeID],
          Type.lit(typeExprType),
          Literal.mk(typeExprType, returnType),
        ),
      ]);

  static Object mk({
    required ID argID,
    required String argName,
    required Object body,
    Object? closure,
  }) =>
      Dict({
        argIDID: argID,
        argNameID: argName,
        bodyID: body,
        closureID: closure ?? List.mk(const []),
      });

  static Object mkDartBody(ID body) => UnionTag.mk(dartID, body);

  static ID argID(Object fn) => (fn as Dict)[argIDID].unwrap! as ID;
  static String argName(Object fn) => (fn as Dict)[argNameID].unwrap! as String;
  static Iterable<Object> closure(Object fn) => List.iterate((fn as Dict)[closureID].unwrap!);
  static Object bodyCases(
    Object fn, {
    required Object Function(Object) pal,
    required Object Function(ID) dart,
  }) {
    final body = (fn as Dict)[bodyID].unwrap!;
    if (UnionTag.tag(body) == palID) {
      return pal(UnionTag.value(body));
    } else if (UnionTag.tag(body) == dartID) {
      return dart(UnionTag.value(body) as ID);
    } else {
      throw Exception('unknown FnValue body tag ${UnionTag.tag(body)}');
    }
  }
}

abstract class FnExpr extends Expr {
  static final argIDID = ID('argID');
  static final argNameID = ID('argName');
  static final argTypeID = ID('argType');
  static final returnTypeID = ID('returnType');
  static final bodyID = ID('body');
  static final palID = ID('pal');
  static final dartID = ID('dart');

  static final typeDefID = ID('FnExpr');
  static final typeDef = TypeDef.record(
    'FnExpr',
    {
      argTypeID: TypeTree.mk('argType', Type.lit(Expr.type)),
      returnTypeID: TypeTree.mk('returnType', Type.lit(Option.type(Expr.type))),
      argIDID: TypeTree.mk('argID', Type.lit(ID.type)),
      argNameID: TypeTree.mk('argName', Type.lit(text)),
      bodyID: TypeTree.union('body', {
        palID: TypeTree.mk('pal', Type.lit(Expr.type)),
        dartID: TypeTree.mk('dart', Type.lit(ID.type)),
      }),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final exprImplID = ID('FnExprImpl');

  static const typeFnBody = ID.from(id: '916ccdd7-75de-4c37-b728-a318b101aff7');

  static const reduceFnBody = ID.from(id: 'a814d41c-2b9b-49a0-afc2-9c6c25e47468');

  static const evalFnBody = ID.from(id: '738cb307-4b48-4bf2-907b-e06e1e42a49a');

  static final exprImplDef = Expr.mkImplDef(
    id: exprImplID,
    argName: 'fnData',
    dataType: type,
    typeCheckBody: typeFnBody,
    reduceBody: reduceFnBody,
    evalBody: evalFnBody,
  );

  static final Object exprImpl = Expr.mkImpl(
    dataType: type,
    argName: 'fnData',
    typeCheckBody: typeFnBody,
    reduceBody: reduceFnBody,
    evalBody: evalFnBody,
  );

  static Object _mk({
    ID? argID,
    required String argName,
    required Object argType,
    Object? returnType,
    required Object body,
  }) =>
      Expr.mk(
        impl: exprImpl,
        data: Dict({
          argTypeID: argType,
          returnTypeID: Option.mk(returnType),
          argNameID: argName,
          argIDID: argID ?? ID(argName),
          bodyID: body,
        }),
      );

  static Object pal({
    ID? argID,
    required String argName,
    required Object argType,
    required Object returnType,
    required Object body,
  }) =>
      _mk(
        argID: argID,
        argName: argName,
        argType: argType,
        returnType: returnType,
        body: UnionTag.mk(palID, body),
      );

  static Object palInferred({
    ID? argID,
    required String argName,
    required Object argType,
    required Object body,
  }) =>
      _mk(argID: argID, argName: argName, argType: argType, body: UnionTag.mk(palID, body));

  static Object dart({
    ID? argID,
    required String argName,
    required Object argType,
    required Object returnType,
    required ID body,
  }) =>
      _mk(
        argID: argID,
        argName: argName,
        argType: argType,
        returnType: returnType,
        body: UnionTag.mk(dartID, body),
      );

  static Object from({
    required String argName,
    required Object argType,
    required Object Function(Object) returnType,
    required Object Function(Object) body,
  }) {
    final argID = ID(argName);
    return FnExpr.pal(
      argID: argID,
      argName: argName,
      argType: argType,
      returnType: returnType(Var.mk(argID)),
      body: body(Var.mk(argID)),
    );
  }

  static ID argID(Object fnExpr) => (fnExpr as Dict)[argIDID].unwrap! as ID;
  static String argName(Object fnExpr) => (fnExpr as Dict)[argNameID].unwrap! as String;
  static Object argType(Object fn) => (fn as Dict)[argTypeID].unwrap!;
  static Object returnType(Object fn) => (fn as Dict)[returnTypeID].unwrap!;
  static Object body(Object fn) => (fn as Dict)[bodyID].unwrap!;
  static T bodyCases<T>(
    Object fn, {
    required T Function(Object) pal,
    required T Function(ID) dart,
  }) {
    final body = (fn as Dict)[bodyID].unwrap!;
    if (UnionTag.tag(body) == palID) {
      return pal(UnionTag.value(body));
    } else {
      return dart(UnionTag.value(body) as ID);
    }
  }
}

abstract class FnApp extends Expr {
  static final fnID = ID('fn');
  static final argID = ID('arg');

  static final typeDef = TypeDef.mk(TypeTree.record('FnApp', {
    fnID: TypeTree.mk('fn', Type.lit(Expr.type)),
    argID: TypeTree.mk('arg', Type.lit(Expr.type)),
  }));
  static final type = TypeDef.asType(typeDef);

  static const _typeFnBody = ID.from(id: 'be6e4c77-a9fb-4d10-92cc-338c59ec3d5b');
  static const _reduceFnBody = ID.from(id: '64923943-f567-44dd-afb9-bf8a28ea7719');
  static const _evalFnBody = ID.from(id: 'bb3a9958-31b9-4309-9113-5bbda9b7da19');

  static final exprImplDef = Expr.mkImplDef(
    argName: 'fnAppData',
    dataType: type,
    typeCheckBody: _typeFnBody,
    reduceBody: _reduceFnBody,
    evalBody: _evalFnBody,
  );

  static final Object exprImpl = Expr.mkImpl(
    argName: 'fnAppData',
    dataType: type,
    typeCheckBody: _typeFnBody,
    reduceBody: _reduceFnBody,
    evalBody: _evalFnBody,
  );

  static Object mk(Object fn, Object arg) => Expr.mk(
        impl: exprImpl,
        data: Dict({fnID: fn, argID: arg}),
      );

  static Object fn(Object fnApp) => (fnApp as Dict)[fnID].unwrap!;
  static Object arg(Object fnApp) => (fnApp as Dict)[argID].unwrap!;
}

class MyException implements Exception {
  const MyException();
}

abstract class Construct extends Expr {
  static final dataTypeID = ID('dataType');
  static final treeID = ID('tree');

  static final typeDefID = ID('Construct');
  static final typeDef = TypeDef.record(
    'Construct',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      treeID: TypeTree.mk('tree', Type.lit(unit)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static const _typeFn = ID.from(id: '3b12dfa7-b5d6-4bf3-bc0f-47efdb9e46ce');

  static const _reduceFn = ID.from(id: '7a0fc27e-4511-463e-bc56-1445de7d65a8');

  static const _evalFn = ID.from(id: 'ff147616-dbb9-4759-9184-5aa800572852');

  static final exprImplID = ID('ConstructExprImpl');
  static final exprImplDef = Expr.mkImplDef(
    id: exprImplID,
    argName: 'constructData',
    dataType: type,
    typeCheckBody: _typeFn,
    reduceBody: _reduceFn,
    evalBody: _evalFn,
  );
  static final Object exprImpl = Expr.mkImpl(
    argName: 'constructData',
    dataType: type,
    typeCheckBody: _typeFn,
    reduceBody: _reduceFn,
    evalBody: _evalFn,
  );

  static Object dataType(Object construct) => (construct as Dict)[dataTypeID].unwrap!;
  static Object tree(Object construct) => (construct as Dict)[treeID].unwrap!;

  static Object mk(Object dataType, Object tree) => Expr.mk(
        impl: exprImpl,
        data: Dict({dataTypeID: dataType, treeID: tree}),
      );
}

abstract class RecordAccess extends Expr {
  static final targetID = ID('target');
  static final memberID = ID('member');

  static final typeDefID = ID('RecordAccess');
  static final typeDef = TypeDef.record(
    'RecordAccess',
    {
      targetID: TypeTree.mk('target', Type.lit(Expr.type)),
      memberID: TypeTree.mk('accessed', Type.lit(ID.type)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static const _typeFn = ID.from(id: '82bf53a9-470a-4a7c-9326-e367397c56d4');

  static const _reduceFn = ID.from(id: '9685059c-a3b5-4964-882d-107151dc7802');

  static const _evalFn = ID.from(id: 'e0018149-0f3c-4ddd-bcef-9c681cee4ddd');

  static final exprImplID = ID('exprImpl');
  static final exprImplDef = Expr.mkImplDef(
    id: exprImplID,
    argName: 'recordAccessData',
    dataType: TypeDef.asType(typeDef),
    typeCheckBody: _typeFn,
    reduceBody: _reduceFn,
    evalBody: _evalFn,
  );
  static final Object exprImpl = Expr.mkImpl(
    dataType: type,
    argName: 'recordAccessData',
    typeCheckBody: _typeFn,
    reduceBody: _reduceFn,
    evalBody: _evalFn,
  );

  static Object mk(Object target, Object member) => Expr.mk(
        data: Dict({targetID: target, memberID: member}),
        impl: exprImpl,
      );

  static Object chain(Object target, DartList members) => members.fold(target, mk);

  static Object target(Object dataAccess) => (dataAccess as Dict)[targetID].unwrap!;
  static ID member(Object dataAccess) => (dataAccess as Dict)[memberID].unwrap! as ID;
}

abstract class Literal extends Expr {
  static final typeID = ID('type');
  static final valueID = ID('value');

  static final typeDefID = ID('Literal');
  static final typeDef = TypeDef.record(
    'Literal',
    {
      typeID: TypeTree.mk('type', Type.lit(Type.type)),
      valueID: TypeTree.mk('value', Var.mk(typeID)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static const _typeFnData = ID.from(id: '5249e346-b160-4a03-b657-2002027596be');

  static const _reduceFnData = ID.from(id: '407672c9-89c1-4c56-ae90-61114500136a');

  static const _evalFnData = ID.from(id: 'e53622ea-9e07-48c1-bcb2-3376ae9eb0f5');

  static final exprImplID = ID('LiteralExprImpl');
  static final exprImplDef = Expr.mkImplDef(
    id: exprImplID,
    argName: 'literalData',
    dataType: type,
    typeCheckBody: _typeFnData,
    reduceBody: _reduceFnData,
    evalBody: _evalFnData,
  );
  static final Object exprImpl = Expr.mkImpl(
    dataType: type,
    argName: 'literalData',
    typeCheckBody: _typeFnData,
    reduceBody: _reduceFnData,
    evalBody: _evalFnData,
  );

  static Object mk(Object type, Object value) => Expr.mk(
        impl: exprImpl,
        data: Dict({typeID: type, valueID: value}),
      );

  static Object getType(Object literal) => (literal as Dict)[typeID].unwrap!;
  static Object getValue(Object literal) => (literal as Dict)[valueID].unwrap!;
}

abstract class Var extends Expr {
  static final IDID = ID('ID');
  static final typeDefID = ID('Var');
  static final typeDef = TypeDef.record(
    'Var',
    {
      IDID: TypeTree.mk('id', Type.lit(ID.type)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static const _typeFn = ID.from(id: '3e9ec939-8b06-4ae1-b994-6d9ffce15b61');
  static const _reduceFn = ID.from(id: '6c0432ae-e016-4c21-9579-2e8c6e15412d');
  static const _evalFn = ID.from(id: '71220800-2abd-40c3-b97a-5b8b1b743e6f');

  static final exprImplDef = Expr.mkImplDef(
    dataType: type,
    argName: 'varData',
    typeCheckBody: _typeFn,
    reduceBody: _reduceFn,
    evalBody: _evalFn,
  );
  static final exprImpl = Expr.mkImpl(
    dataType: type,
    argName: 'varData',
    typeCheckBody: _typeFn,
    reduceBody: _reduceFn,
    evalBody: _evalFn,
  );

  static Object mk(ID varID) => Expr.mk(
        impl: exprImpl,
        data: Dict({IDID: varID}),
      );

  static ID id(Object varAccess) => (varAccess as Dict)[IDID].unwrap! as ID;
}

abstract class Placeholder extends Expr {
  static final typeDef = TypeDef.unit('Placeholder');

  static final exprImplDef = Expr.mkImplDef(
    dataType: TypeDef.asType(typeDef),
    argName: 'placeholderData',
    typeCheckBody: const ID.from(id: 'b1750fd4-b07f-490b-816f-7933361115e5'),
    reduceBody: const ID.from(id: 'd695423c-c03f-4f9f-beb6-0d615eb938d9'),
    evalBody: const ID.from(id: '587c85cd-5ce2-4fb0-92a1-3e86086e1154'),
  );
}

final placeholder = Expr.mk(
  data: const Dict(),
  impl: ImplDef.asImpl(Ctx.empty.withFnMap(coreFnMap), Expr.interfaceDef, Placeholder.exprImplDef),
);

extension CtxType on Ctx {
  Object getType(ID id) => Option.unwrap(
        Binding.value(
          this,
          Option.cases(
            getBinding(id),
            some: (_) => _,
            none: () => throw Exception('unknown type $id'),
          ),
        ),
      );
  Iterable<Object> get getTypes => getBindings.expand((binding) => [
        if (Binding.valueType(this, binding) == TypeDef.type)
          Option.unwrap(Binding.value(this, binding)),
      ]);

  Object getInterface(ID id) => Option.unwrap(Binding.value(this, Option.unwrap(getBinding(id))));

  Object getImpl(ID id) => Option.unwrap(Binding.value(this, Option.unwrap(getBinding(id))));
}

abstract class Binding {
  static final IDID = ID('ID');
  static final valueTypeID = ID('type');
  static final nameID = ID('name');
  static final reducedValueID = ID('reducedValue');
  static final valueID = ID('value');

  static final def = TypeDef.record('Binding', {
    IDID: TypeTree.mk('id', Type.lit(ID.type)),
    valueTypeID: TypeTree.mk('type', Type.lit(typeExprType)),
    nameID: TypeTree.mk('name', Type.lit(text)),
    reducedValueID: TypeTree.mk(
      'reducedValue',
      Fn.typeExpr(
        argID: ID('_'),
        argType: Type.lit(unit),
        returnType: Option.typeExpr(Expr.type),
      ),
    ),
    valueID: TypeTree.mk(
      'value',
      Fn.typeExpr(
        argID: ID('_'),
        argType: Type.lit(unit),
        returnType: Option.typeExpr(Var.mk(valueTypeID)),
      ),
    ),
  });
  static final type = TypeDef.asType(def);

  static Object mk({
    required ID id,
    required Object? type,
    required String name,
    Object? reducedValue,
    Object? value,
  }) =>
      Dict({
        IDID: id,
        valueTypeID: (Ctx _) =>
            type ?? (throw Exception('shouldn\'t be trying to access this binding\'s type!!!')),
        nameID: name,
        reducedValueID: (Ctx _) => Option.mk(reducedValue),
        valueID: (Ctx _) => Option.mk(value),
      });

  static Object mkLazy({
    required ID id,
    required Object Function(Ctx)? type,
    required String name,
    Object? Function(Ctx)? reducedValue,
    Object? Function(Ctx)? value,
  }) =>
      Dict({
        IDID: id,
        valueTypeID: (Ctx ctx) => (type ??
            (throw Exception('shouldn\'t be trying to access this binding\'s type!!!')))(ctx),
        nameID: name,
        reducedValueID: (Ctx ctx) => Option.mk(reducedValue == null ? null : reducedValue(ctx)),
        valueID: (Ctx ctx) => Option.mk(value == null ? null : value(ctx))
      });

  static ID id(Object binding) => (binding as Dict)[IDID].unwrap! as ID;
  static Object valueType(Ctx ctx, Object binding) =>
      ((binding as Dict)[valueTypeID].unwrap! as Object Function(Ctx))(ctx);
  static String name(Object binding) => (binding as Dict)[nameID].unwrap! as String;
  static Object reducedValue(Ctx ctx, Object binding) =>
      ((binding as Dict)[reducedValueID].unwrap! as Object Function(Ctx))(ctx);
  static Object value(Ctx ctx, Object binding) =>
      ((binding as Dict)[valueID].unwrap! as Object Function(Ctx))(ctx);
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
      Option.mk((get<BindingCtx>() ?? const BindingCtx()).bindings[id].unwrap);
  Iterable<Object> get getBindings => (get<BindingCtx>() ?? const BindingCtx()).bindings.values;
}

final coreCtx = (Option.unwrap(Module.load(Ctx.empty.withFnMap(coreFnMap), coreModule)) as Ctx);

final _substBindingID = ID('subst');
dart.Map<ID, Object> _subst(Ctx ctx) {
  return Option.unwrap(Binding.value(ctx, Option.unwrap(ctx.getBinding(_substBindingID))))
      as dart.Map<ID, Object>;
}

Ctx _initSubst(Ctx ctx) {
  return Option.cases(
    ctx.getBinding(_substBindingID),
    some: (_) => ctx,
    none: () => ctx.withBinding(
      Binding.mk(id: _substBindingID, type: null, name: 'subst', value: <ID, Object>{}),
    ),
  );
}

dart.Map<ID, Object>? assignableSubst(Ctx ctx, Object a, Object b) {
  ctx = _initSubst(ctx);
  if (assignableImpl(ctx, a, b)) return _subst(ctx);
  return null;
}

bool assignable(Ctx ctx, Object a, Object b) => assignableImpl(_initSubst(ctx), a, b);

bool assignableImpl(Ctx ctx, Object a, Object b) {
  if (a == b) {
    return true;
  } else if ({RecordAccess.type, Var.type}.contains(Expr.dataType(a))) {
    if (_subst(ctx).containsKey(_exprToBindingID(a))) {
      return assignableImpl(ctx, _subst(ctx)[a]!, b);
    }
    if ({RecordAccess.type, Var.type}.contains(Expr.dataType(b))) {
      if (_subst(ctx).containsKey(_exprToBindingID(b))) {
        return assignableImpl(ctx, a, _subst(ctx)[b]!);
      }
    }
    if (occurs(ctx, _exprToBindingID(a), b)) return false;
    _subst(ctx)[_exprToBindingID(a)] = b;
    return true;
  } else if ({RecordAccess.type, Var.type}.contains(Expr.dataType(b))) {
    return false;
  } else if ({Literal.type, Construct.type}.contains(Expr.dataType(a))) {
    if (!{Literal.type, Construct.type}.contains(Expr.dataType(b))) return false;
    final typeA = _litOrConsType(a);
    final typeB = _litOrConsType(a);
    if (!assignableImpl(ctx, Type.lit(typeA), Type.lit(typeB))) {
      return false;
    }
    if (Type.id(typeA) == Type.id(Type.type)) {
      if (reduce(ctx, RecordAccess.mk(a, Type.IDID)) !=
          reduce(ctx, RecordAccess.mk(b, Type.IDID))) {
        return false;
      }
      for (final propertyA in Type.exprIterateProperties(ctx, a)) {
        if (TypeProperty.exprDataType(ctx, propertyA) == MemberHas.type) {
          final memberHasA = reduce(ctx, RecordAccess.mk(propertyA, TypeProperty.dataID));
          final pathA = Literal.getValue(Expr.data(
            reduce(ctx, RecordAccess.mk(memberHasA, MemberHas.pathID)),
          ));
          for (final propertyB in Type.exprIterateProperties(ctx, b)) {
            if (TypeProperty.exprDataType(ctx, propertyB) == MemberHas.type) {
              final memberHasB = reduce(ctx, RecordAccess.mk(propertyB, TypeProperty.dataID));
              final pathB = Literal.getValue(Expr.data(
                reduce(ctx, RecordAccess.mk(memberHasB, MemberHas.pathID)),
              ));
              if (pathA != pathB) continue;
              final equalsA = reduce(
                ctx,
                RecordAccess.chain(memberHasA, [MemberHas.propertyID, TypeProperty.dataID]),
              );
              final equalsB = reduce(
                ctx,
                RecordAccess.chain(memberHasB, [MemberHas.propertyID, TypeProperty.dataID]),
              );
              if (!assignableImpl(ctx, equalsA, equalsB)) return false;
            } else {
              throw UnimplementedError(
                'assignableImpl for type property ${TypeProperty.exprDataType(ctx, propertyA)}',
              );
            }
          }
        } else {
          throw UnimplementedError(
            'assignableImpl for type property ${TypeProperty.exprDataType(ctx, propertyA)}',
          );
        }
      }
    } else {
      final typeDef = ctx.getType(Type.id(typeA));
      Object wrapTree(Ctx ctx, Object expr) {
        if (Expr.dataType(expr) == Construct.type) return Construct.tree(Expr.data(expr));
        ctx = TypeTree.foldData<DartList>(
          [],
          TypeDef.tree(typeDef),
          Literal.getValue(Expr.data(expr)),
          (bindings, typeLeaf, dataLeaf, path) => [
            ...bindings,
            Binding.mk(id: (path.last as ID), type: null, name: '', value: dataLeaf)
          ],
        ).fold(ctx, (ctx, binding) => ctx.withBinding(binding));

        return TypeTree.mapData(
          TypeDef.tree(typeDef),
          Literal.getValue(Expr.data(expr)),
          (typeLeaf, dataLeaf, path) => Literal.mk(eval(ctx, typeLeaf), dataLeaf),
        );
      }

      bool recurse(Object typeTree, Object aData, Object bData) {
        return TypeTree.treeCases(
          typeTree,
          record: (record) => record.entries.every(
            (entry) => recurse(
              entry.value,
              (aData as Dict)[entry.key].unwrap!,
              (bData as Dict)[entry.key].unwrap!,
            ),
          ),
          union: (union) {
            if (UnionTag.tag(aData) != UnionTag.tag(bData)) return false;
            return recurse(
              union[UnionTag.tag(aData)].unwrap!,
              UnionTag.value(aData),
              UnionTag.value(bData),
            );
          },
          leaf: (leaf) {
            return assignableImpl(ctx, aData, bData);
          },
        );
      }

      return recurse(
        TypeDef.tree(typeDef),
        wrapTree(ctx, a),
        wrapTree(ctx, b),
      );
    }
    return true;
  } else {
    throw UnimplementedError('assignableImpl for expr type ${Expr.dataType(a)}');
  }
}

Object _litOrConsType(Object litOrCons) {
  if (Expr.dataType(litOrCons) == Construct.type) {
    return Construct.dataType(Expr.data(litOrCons));
  } else if (Expr.dataType(litOrCons) == Literal.type) {
    return Literal.getType(Expr.data(litOrCons));
  } else {
    throw UnimplementedError('_litOrConsType on Expr type: ${Expr.dataType(litOrCons)}');
  }
}

ID _exprToBindingID(Object typeExpr) {
  if (Expr.dataType(typeExpr) == RecordAccess.type) {
    return _exprToBindingID(RecordAccess.target(Expr.data(typeExpr)))
        .append(RecordAccess.member(Expr.data(typeExpr)));
  } else if (Expr.dataType(typeExpr) == Var.type) {
    return Var.id(Expr.data(typeExpr));
  } else {
    throw UnimplementedError('_exprToBindingID on Expr type: ${Expr.dataType(typeExpr)}');
  }
}

bool occurs(Ctx ctx, ID a, Object b) {
  if (Expr.dataType(b) == Literal.type) return false;
  if ({RecordAccess.type, Var.type}.contains(Expr.dataType(b))) return _exprToBindingID(b) == a;
  if (Expr.dataType(b) == Construct.type) {
    final typeDef = ctx.getType(Type.id(Construct.dataType(Expr.data(b))));
    return TypeTree.foldData(
      false,
      TypeDef.tree(typeDef),
      Construct.tree(Expr.data(b)),
      (prev, _, dataLeaf, __) => prev || occurs(ctx, a, dataLeaf),
    );
  } else if (Expr.dataType(b) == List.mkExprType) {
    return List.iterate(List.mkExprValues(Expr.data(b))).any((subExpr) => occurs(ctx, a, subExpr));
  } else {
    throw Exception('occurs not implemented for expr ${Expr.dataType(b)}');
  }
}

dart.Set<ID> freeVars(Ctx ctx, Object expr) {
  if (Expr.dataType(expr) == Literal.type) return const {};
  if (Expr.dataType(expr) == RecordAccess.type) {
    return freeVars(ctx, RecordAccess.target(Expr.data(expr)));
  }
  if (Expr.dataType(expr) == Var.type) return {Var.id(Expr.data(expr))};
  if (Expr.dataType(expr) == Construct.type) {
    final typeDef = ctx.getType(Type.id(Construct.dataType(Expr.data(expr))));

    final consVars = <ID>{};
    return TypeTree.foldData<dart.Set<ID>>(
      const {},
      TypeDef.tree(typeDef),
      Construct.tree(Expr.data(expr)),
      (prev, _, dataLeaf, path) {
        consVars.add(path.last as ID);
        return prev.union(freeVars(ctx, dataLeaf));
      },
    );
  } else if (Expr.dataType(expr) == List.mkExprType) {
    return List.iterate(List.mkExprValues(Expr.data(expr)))
        .fold(const {}, (prev, subExpr) => prev.union(freeVars(ctx, subExpr)));
  } else if (Expr.dataType(expr) == FnApp.type) {
    return freeVars(ctx, FnApp.fn(Expr.data(expr)))
        .union(freeVars(ctx, FnApp.arg(Expr.data(expr))));
  } else if (Expr.dataType(expr) == FnExpr.type) {
    final bodyVars = FnExpr.bodyCases<dart.Set<ID>>(
      Expr.data(expr),
      dart: (_) => const {},
      pal: (body) => freeVars(ctx, body),
    );
    final returnTypeVars = Option.cases(
      FnExpr.returnType(Expr.data(expr)),
      some: (returnType) => freeVars(ctx, returnType),
      none: () => const <ID>{},
    );
    final argVar = {FnExpr.argID(Expr.data(expr))};
    final argTypeVars = freeVars(ctx, FnExpr.argType(Expr.data(expr)));
    return bodyVars.union(returnTypeVars).difference(argVar).union(argTypeVars);
  } else {
    throw Exception('freeVars not implemented for expr ${Expr.dataType(expr)}');
  }
}

Object varSubst(Ctx ctx, ID fromID, ID toID, Object expr) {
  final exprType = Expr.dataType(expr);
  final exprData = Expr.data(expr);
  if (exprType == Var.type) {
    return Var.id(exprData) == fromID ? Var.mk(toID) : expr;
  } else if (exprType == Literal.type) {
    return expr;
  } else if (exprType == RecordAccess.type) {
    return RecordAccess.mk(
      varSubst(ctx, fromID, toID, RecordAccess.target(exprData)),
      RecordAccess.member(exprData),
    );
  } else if (exprType == Construct.type) {
    return Construct.mk(
      Construct.dataType(exprData),
      TypeTree.mapData(
        TypeDef.tree(ctx.getType(Type.id(Construct.dataType(exprData)))),
        Construct.tree(exprData),
        (_, data, __) => varSubst(ctx, fromID, toID, data),
      ),
    );
  } else if (exprType == List.mkExprType) {
    return List.mkExpr(
      List.mkExprDataType(exprData),
      [...List.iterate(List.mkExprValues(exprData)).map((e) => varSubst(ctx, fromID, toID, e))],
    );
  } else {
    throw UnimplementedError('subst on expr type $exprType');
  }
}

Object dispatch(Ctx ctx, ID interfaceID, Object type) {
  Object? bestImpl;
  Object? bestArg;
  Object? bestType;
  for (final binding in ctx.getBindings) {
    if (!ImplDef.bindingIDPrefixForID(interfaceID).isPrefixOf(Binding.id(binding))) continue;
    final bindingType = Literal.getValue(
      Expr.data(
        Type.exprMemberEquals(ctx, Binding.valueType(ctx, binding), [Fn.returnTypeID]),
      ),
    );
    final argType = Literal.getValue(
      Expr.data(Type.exprMemberEquals(ctx, Binding.valueType(ctx, binding), [Fn.argTypeID])),
    );
    ctx = ctx.withBinding(
      Binding.mk(id: ImplDef.definitionArgID, type: Type.lit(argType), name: 'definitionArg'),
    );
    final subst = assignableSubst(ctx, bindingType, Type.lit(type));
    if (subst == null) continue;
    if (bestType != null) {
      if (assignable(
        ctx,
        bindingType,
        varSubst(ctx, ImplDef.definitionArgID, ID().append(ImplDef.definitionArgID), bestType),
      )) continue;

      if (!assignable(
        ctx,
        bestType,
        varSubst(ctx, ImplDef.definitionArgID, ID().append(ImplDef.definitionArgID), bindingType),
      )) return Option.mk();
    }
    bestType = bindingType;
    bestImpl = Option.unwrap(Binding.value(ctx, binding));
    bestArg = _extractSubstArg(ctx, argType, subst);
  }
  // TODO: the type in the literal is wrong but it doesn't rly matter
  return Option.mk(
    bestImpl == null ? null : eval(ctx, FnApp.mk(Type.lit(bestImpl), bestArg!)),
  );
}

Object _extractSubstArg(Ctx ctx, Object type, dart.Map<ID, Object> subst) {
  if (subst.containsKey(ImplDef.definitionArgID)) {
    return subst[ImplDef.definitionArgID]!;
  }
  final typeDef = ctx.getType(Type.id(type));
  var notFound = false;
  Object recurse(ID path, Object typeTree) {
    return TypeTree.treeCases(
      typeTree,
      record: (record) {
        return Dict({
          for (final entry in record.entries)
            if (!TypeDef.comptime(typeDef).contains(entry.key))
              entry.key: recurse(path.append(entry.key as ID), entry.value),
        });
      },
      union: (_) => throw UnimplementedError(),
      leaf: (leaf) {
        if (subst.containsKey(path)) return subst[path]!;
        notFound = true;
        return const Dict({});
      },
    );
  }

  final constructExpr = Construct.mk(
    type,
    TypeTree.augmentTree(type, recurse(ImplDef.definitionArgID, TypeDef.tree(typeDef))),
  );
  if (notFound) return unitExpr;
  return constructExpr;
}

Object eval(Ctx ctx, Object expr) {
  final data = Expr.data(expr);
  final dataType = Expr.dataType(expr);
  final evalExprData = Expr.evalExpr(expr);
  return Fn.bodyCases(
    evalExprData,
    pal: (bodyExpr) {
      return eval(
        ctx.withBinding(Binding.mk(
          id: Fn.argID(evalExprData),
          // TODO: this is wronggg?
          type: Type.lit(dataType),
          name: Fn.argName(evalExprData),
          value: data,
        )),
        bodyExpr,
      );
    },
    dart: (bodyFn) {
      return ctx.getFn(bodyFn)(ctx, data);
    },
  );
}

final _visitedID = ID('visited');
Ctx updateVisited(Ctx ctx, ID id) {
  final prevSet = Option.cases(
    ctx.getBinding(_visitedID),
    some: (visitedBinding) => Option.unwrap(Binding.value(ctx, visitedBinding)) as Set,
    none: () => const Set(),
  );
  if (prevSet.contains(id)) throw const MyException();
  return ctx.withBinding(
    Binding.mk(
      id: _visitedID,
      name: 'visited',
      type: Type.lit(unit),
      value: prevSet.add(id),
    ),
  );
}

Object reduce(Ctx ctx, Object expr) => eval(
      ctx,
      FnApp.mk(Expr.reduceFn, Literal.mk(Expr.type, expr)),
    );

Object typeCheck(Ctx ctx, Object expr) => eval(
      ctx,
      FnApp.mk(Expr.typeCheckFn, Literal.mk(Expr.type, expr)),
    );

Object? _toEncodable(dynamic arg) {
  if (arg is Dict) {
    return {for (final entry in arg.entries) serialize(entry.key, ''): entry.value};
  } else if (arg is Vec) {
    return arg.toList();
  } else if (arg is ID) {
    return arg.id + (arg.tail == null ? '' : '.${_toEncodable(arg.tail)}');
  } else {
    throw UnimplementedError('_toEncodable on ${arg.runtimeType}');
  }
}

String serialize(Object arg, String indent) =>
    JsonEncoder.withIndent(indent, _toEncodable).convert(arg);
dynamic _revive(final dynamic arg) {
  if (arg is dart.Map<String, dynamic>) {
    return Dict(arg.map(
        (key, dynamic value) => MapEntry(deserialize(key) as Object, _revive(value) as Object)));
  } else if (arg is dart.List<dynamic>) {
    return Vec([...arg.map<dynamic>(_revive).cast<Object>()]);
  } else if (arg is String) {
    return _tryReviveID(arg) ?? arg;
  } else {
    return arg;
  }
}

ID? _tryReviveID(String string) {
  if (string.length < 36) return null;
  final prefix = string.substring(0, 36);
  final suffix = string.substring(36);
  if (Uuid.isValidUUID(fromString: string.substring(0, 36))) {
    if (suffix.isEmpty) return ID.from(id: prefix, label: null, tail: null);
    if (!suffix.startsWith('.')) return null;
    final tail = _tryReviveID(suffix.substring(1));
    if (tail == null) return null;
    return ID.from(id: prefix, label: null, tail: tail);
  }
  return null;
}

final _decoder = JsonDecoder((_, arg) => _revive(arg));
dynamic deserialize(String json) => _decoder.convert(json);

class FnMapCtx extends CtxElement {
  final FnMap fnMap;

  FnMapCtx(this.fnMap);
}

extension FnMapCtxExt on Ctx {
  Ctx withFnMap(FnMap map) =>
      withElement(FnMapCtx({if (get<FnMapCtx>() != null) ...get<FnMapCtx>()!.fnMap, ...map}));

  Object Function(Ctx, Object) getFn(ID id) => get<FnMapCtx>()!.fnMap[id]!;
}

final coreModule = Module.mk(name: 'core', definitions: [
  TypeDef.mkDef(ID.def),
  TypeDef.mkDef(Module.def),
  InterfaceDef.mkDef(ModuleDef.interfaceDef),
  TypeDef.mkDef(ModuleDef.typeDef),
  TypeDef.mkDef(ValueDef.typeDef),
  ImplDef.mkDef(ValueDef.moduleDefImplDef),
  TypeDef.mkDef(TypeDef.def),
  ImplDef.mkDef(TypeDef.moduleDefImplDef),
  TypeDef.mkDef(Type.def),
  InterfaceDef.mkDef(TypeProperty.interfaceDef),
  TypeDef.mkDef(TypeProperty.typeDef),
  TypeDef.mkDef(Equals.typeDef),
  ImplDef.mkDef(Equals.propImplDef),
  TypeDef.mkDef(MemberHas.typeDef),
  ImplDef.mkDef(MemberHas.propImplDef),
  TypeDef.mkDef(UnionTag.def),
  TypeDef.mkDef(Union.def),
  TypeDef.mkDef(Pair.def),
  TypeDef.mkDef(TypeTree.def),
  TypeDef.mkDef(InterfaceDef.def),
  ImplDef.mkDef(InterfaceDef.moduleDefImplDef),
  TypeDef.mkDef(ImplDef.def),
  ImplDef.mkDef(ImplDef.moduleDefImplDef),
  TypeDef.mkDef(Option.def),
  TypeDef.mkDef(Expr.def),
  InterfaceDef.mkDef(Expr.interfaceDef),
  TypeDef.mkDef(List.def),
  TypeDef.mkDef(List.exprTypeDef),
  ImplDef.mkDef(List.mkExprImplDef),
  TypeDef.mkDef(Map.def),
  // TypeDef.mkDef(Map.exprDataDef),
  // ImplDef.mkDef(Map.mkExprImplDef),
  TypeDef.mkDef(Any.def),
  TypeDef.mkDef(textDef),
  TypeDef.mkDef(numberDef),
  TypeDef.mkDef(booleanDef),
  TypeDef.mkDef(unitDef),
  TypeDef.mkDef(bottomDef),
  TypeDef.mkDef(Fn.typeDef),
  TypeDef.mkDef(FnExpr.typeDef),
  ImplDef.mkDef(FnExpr.exprImplDef),
  TypeDef.mkDef(FnApp.typeDef),
  ImplDef.mkDef(FnApp.exprImplDef),
  TypeDef.mkDef(Construct.typeDef),
  ImplDef.mkDef(Construct.exprImplDef),
  TypeDef.mkDef(RecordAccess.typeDef),
  ImplDef.mkDef(RecordAccess.exprImplDef),
  TypeDef.mkDef(Literal.typeDef),
  ImplDef.mkDef(Literal.exprImplDef),
  TypeDef.mkDef(Var.typeDef),
  ImplDef.mkDef(Var.exprImplDef),
  TypeDef.mkDef(Placeholder.typeDef),
  ImplDef.mkDef(Placeholder.exprImplDef),
  TypeDef.mkDef(Binding.def),
]);

final FnMap coreFnMap = {
  const ID.from(id: '587c85cd-5ce2-4fb0-92a1-3e86086e1154'): (_, __) =>
      throw Exception("don't evaluate a placeholder u fool!"),
  const ID.from(id: 'd695423c-c03f-4f9f-beb6-0d615eb938d9'): (_, __) =>
      throw Exception("don't reduce a placeholder u fool!"),
  const ID.from(id: 'b1750fd4-b07f-490b-816f-7933361115e5'): (_, __) => Option.mk(),
  const ID.from(id: '71220800-2abd-40c3-b97a-5b8b1b743e6f'): (Ctx ctx, Object arg) {
    return Option.cases(
      Binding.value(
        ctx,
        Option.cases(
          ctx.getBinding(Var.id(arg)),
          some: (binding) => binding,
          none: () => throw Exception(),
        ),
      ),
      some: (val) => val,
      none: () => throw Exception('impossible!!'),
    );
  },
  const ID.from(id: '6c0432ae-e016-4c21-9579-2e8c6e15412d'): (Ctx ctx, Object arg) {
    return Option.cases(
      ctx.getBinding(Var.id(arg)),
      none: () => Var.mk(Var.id(arg)),
      some: (binding) => Option.cases(
        Binding.value(
          ctx,
          binding,
        ),
        some: (val) => Literal.mk(
          Literal.getValue(Expr.data(Binding.valueType(ctx, binding))),
          val,
        ),
        none: () => Option.cases(
          Binding.reducedValue(ctx, binding),
          some: (reducedValue) => reduce(ctx, reducedValue),
          none: () => Var.mk(Var.id(arg)),
        ),
      ),
    );
  },
  const ID.from(id: '3e9ec939-8b06-4ae1-b994-6d9ffce15b61'): (Ctx ctx, Object arg) {
    return Option.cases(
      ctx.getBinding(Var.id(arg)),
      some: (binding) => Option.mk(Binding.valueType(ctx, binding)),
      none: () => Option.mk(),
    );
  },
  const ID.from(id: 'e53622ea-9e07-48c1-bcb2-3376ae9eb0f5'): (Ctx ctx, Object arg) =>
      Literal.getValue(arg),
  const ID.from(id: '407672c9-89c1-4c56-ae90-61114500136a'): (Ctx ctx, Object arg) =>
      Expr.mk(impl: Literal.exprImpl, data: arg),
  const ID.from(id: '5249e346-b160-4a03-b657-2002027596be'): (Ctx ctx, Object arg) =>
      Option.mk(Type.lit(Literal.getType(arg))),
  const ID.from(id: 'e0018149-0f3c-4ddd-bcef-9c681cee4ddd'): (Ctx ctx, Object data) {
    return (eval(ctx, RecordAccess.target(data)) as Dict)[RecordAccess.member(data)].unwrap!;
  },
  const ID.from(id: '9685059c-a3b5-4964-882d-107151dc7802'): (Ctx ctx, Object data) {
    final targetExpr = reduce(ctx, RecordAccess.target(data));
    if (Expr.dataType(targetExpr) == Literal.type) {
      final typeDef = ctx.getType(Type.id(Literal.getType(Expr.data(targetExpr))));
      ctx = TypeTree.foldData<DartList>(
        [],
        TypeDef.tree(typeDef),
        Literal.getValue(Expr.data(targetExpr)),
        (bindings, _, dataLeaf, path) =>
            [...bindings, Binding.mk(id: (path.last as ID), type: null, name: '', value: dataLeaf)],
      ).fold(ctx, (ctx, binding) => ctx.withBinding(binding));

      return (TypeTree.mapData(
        TypeDef.tree(typeDef),
        Literal.getValue(Expr.data(targetExpr)),
        (typeLeaf, dataLeaf, path) => Literal.mk(eval(ctx, typeLeaf), dataLeaf),
      ) as Dict)[RecordAccess.member(data)]
          .unwrap!;
    } else if (Expr.dataType(targetExpr) == Construct.type) {
      return (Construct.tree(Expr.data(targetExpr)) as Dict)[RecordAccess.member(data)].unwrap!;
    } else if (Expr.dataType(targetExpr) == Var.type) {
      return RecordAccess.mk(targetExpr, RecordAccess.member(data));
    }
    throw Exception('reduce record access not implemented for record access!');
  },
  const ID.from(id: '82bf53a9-470a-4a7c-9326-e367397c56d4'): (Ctx ctx, Object arg) {
    return Option.cases(
      typeCheck(ctx, RecordAccess.target(arg)),
      none: () => Option.mk(),
      some: (targetTypeExpr) {
        if (Expr.dataType(targetTypeExpr) == Literal.type) {
          final targetType = Literal.getValue(Expr.data(targetTypeExpr));
          final targetTypeDef = ctx.getType(Type.id(targetType));
          final path = Type.path(targetType);
          final treeAt = TypeTree.treeAt(TypeDef.tree(targetTypeDef), List.iterate(path));
          return TypeTree.treeCases(
            treeAt,
            leaf: (_) => Option.mk(),
            union: (_) => Option.mk(),
            record: (recordNode) {
              final member = RecordAccess.member(arg);
              final subTree = recordNode[member].unwrap!;
              return TypeTree.treeCases(
                subTree,
                record: (_) => (targetType as Dict).put(Type.pathID, List.add(path, member)),
                union: (_) => (targetType as Dict).put(Type.pathID, List.add(path, member)),
                leaf: (leafNode) {
                  final eachEquals = MemberHas.eachEquals(targetType);
                  Iterable<Object> bindings(DartList path, Object typeTree) {
                    return TypeTree.treeCases(
                      typeTree,
                      record: (record) => record.entries.expand(
                        (entry) => bindings([...path, entry.key], entry.value),
                      ),
                      union: (union) => [],
                      leaf: (leaf) => [
                        eachEquals[List.mk(path)].cases(
                          some: (value) => Binding.mk(
                            id: path.last as ID,
                            type: Type.lit(Equals.dataType(value)),
                            name: TypeTree.name(typeTree),
                            value: Equals.equalTo(value),
                          ),
                          none: () {
                            return Binding.mkLazy(
                              id: path.last as ID,
                              name: TypeTree.name(typeTree),
                              type: (ctx) => reduce(ctx, leaf),
                              reducedValue: (ctx) =>
                                  RecordAccess.chain(reduce(ctx, RecordAccess.target(arg)), path),
                            );
                          },
                        )
                      ],
                    );
                  }

                  ctx = bindings([], TypeDef.tree(targetTypeDef)).fold<Ctx>(
                    ctx,
                    (ctx, binding) => ctx.withBinding(binding),
                  );
                  return Option.cases(
                    typeCheck(ctx, leafNode),
                    some: (_) => Option.mk(reduce(ctx, leafNode)),
                    none: () => Option.mk(),
                  );
                },
              );
            },
          );
        } else {
          throw Exception(
            "typechecking recordaccess on non-literal target type not implemented!",
          );
        }
      },
    );
  },
  const ID.from(id: 'ff147616-dbb9-4759-9184-5aa800572852'): (Ctx ctx, Object arg) {
    final typeDef = ctx.getType(Type.id(Construct.dataType(arg)));
    final comptimeIDs = TypeDef.comptime(typeDef);
    return TypeTree.maybeMapData(
      TypeDef.tree(typeDef),
      Construct.tree(arg),
      (_, dataLeaf, path) =>
          Option.mk(comptimeIDs.contains(path.last) ? null : eval(ctx, dataLeaf)),
    );
  },
  const ID.from(id: '7a0fc27e-4511-463e-bc56-1445de7d65a8'): (Ctx ctx, Object arg) {
    bool nonLit = false;
    final typeTree = TypeDef.tree(ctx.getType(Type.id(Construct.dataType(arg))));
    final exprTree = TypeTree.mapData(
      typeTree,
      Construct.tree(arg),
      (_, dataLeaf, __) {
        final reduced = reduce(ctx, dataLeaf);
        if (Expr.dataType(reduced) != Literal.type) nonLit = true;
        return reduced;
      },
    );

    if (nonLit) return Construct.mk(Construct.dataType(arg), exprTree);
    return Literal.mk(
      Construct.dataType(arg),
      TypeTree.mapData(
        typeTree,
        exprTree,
        (_, expr, __) => Literal.getValue(Expr.data(expr)),
      ),
    );
  },
  const ID.from(id: '3b12dfa7-b5d6-4bf3-bc0f-47efdb9e46ce'): (Ctx origCtx, Object arg) {
    final typeDef = origCtx.getType(Type.id(Construct.dataType(arg)));

    final computedProps = <Object>[];
    DartList lazyBindings(Object typeTree, Object dataTree, Object path) {
      return TypeTree.treeCases(
        typeTree,
        record: (record) {
          if (record.length != (dataTree as Dict).length) throw const MyException();
          return [
            ...record.entries.expand((entry) {
              if (!dataTree.containsKey(entry.key)) throw const MyException();
              return lazyBindings(
                entry.value,
                dataTree[entry.key].unwrap!,
                List.add(path, entry.key),
              );
            }),
          ];
        },
        union: (union) {
          final tag = UnionTag.tag(dataTree);
          if (!union.containsKey(tag)) throw const MyException();
          return lazyBindings(union[tag].unwrap!, UnionTag.value(dataTree), List.add(path, tag));
        },
        leaf: (leaf) {
          Object? lazyType;
          Object? lazyValue;
          computeType(Ctx ctx) {
            if (lazyType == null) {
              Option.cases(
                typeCheck(updateVisited(ctx, List.iterate(path).last as ID), leaf),
                some: (checkedType) {
                  if (!assignable(ctx, Type.lit(Type.type), checkedType)) {
                    throw const MyException();
                  }
                },
                none: () => throw const MyException(),
              );
              final defType = reduce(updateVisited(ctx, List.iterate(path).last as ID), leaf);
              lazyType = Option.cases(
                typeCheck(origCtx, dataTree),
                some: (dataType) {
                  if (!assignable(ctx, defType, dataType)) throw const MyException();
                  return dataType;
                },
                none: () => throw const MyException(),
              );
            }
            return lazyType!;
          }

          computeValue(Ctx ctx) {
            if (lazyValue == null) {
              final dataType = computeType(ctx);
              lazyValue = reduce(origCtx, dataTree);
              computedProps.add(
                MemberHas.mkEqualsExpr([...List.iterate(path)], dataType, lazyValue!),
              );
            }
            return lazyValue!;
          }

          return [
            Binding.mkLazy(
              id: List.iterate(path).last as ID,
              name: TypeTree.name(typeTree),
              type: computeType,
              reducedValue: computeValue,
            ),
          ];
        },
      );
    }

    final bindings = lazyBindings(TypeDef.tree(typeDef), Construct.tree(arg), List.mk(const []));
    final typeCtx = bindings.fold<Ctx>(origCtx, (ctx, binding) => ctx.withBinding(binding));
    try {
      for (final binding in bindings) {
        Binding.valueType(typeCtx, binding);
      }
    } on MyException {
      return Option.mk();
    }

    return Option.mk(
      reduce(origCtx, Type.mkExpr(Type.id(Construct.dataType(arg)), properties: computedProps)),
    );
  },
  const ID.from(id: 'bb3a9958-31b9-4309-9113-5bbda9b7da19'): (Ctx ctx, Object data) {
    final fn = eval(ctx, FnApp.fn(data));
    final arg = eval(ctx, FnApp.arg(data));
    return Fn.bodyCases(
      fn,
      pal: (body) => eval(
        Fn.closure(fn).followedBy([
          Binding.mk(
            id: Fn.argID(fn),
            type: null,
            name: Fn.argName(fn),
            value: arg,
          )
        ]).fold(ctx, (ctx, binding) => ctx.withBinding(binding)),
        body,
      ),
      dart: (body) => ctx.getFn(body)(ctx, arg),
    );
  },
  const ID.from(id: '64923943-f567-44dd-afb9-bf8a28ea7719'): (Ctx ctx, Object fnApp) {
    final reducedFn = reduce(ctx, FnApp.fn(fnApp));
    if (Expr.dataType(reducedFn) == Literal.type || Expr.dataType(reducedFn) == FnExpr.type) {
      if (Expr.dataType(reducedFn) == Literal.type) {
        final fnValue = Literal.getValue(Expr.data(reducedFn));
        return Fn.bodyCases(
          fnValue,
          pal: (bodyExpr) {
            return reduce(
              ctx.withBinding(Binding.mk(
                id: Fn.argID(fnValue),
                name: Fn.argName(fnValue),
                type: Literal.mk(
                  Type.type,
                  Type.memberEquals(Literal.getType(Expr.data(reducedFn)), [Fn.argTypeID]),
                ),
              )),
              bodyExpr,
            );
          },
          dart: (_) => Expr.mk(impl: FnApp.exprImpl, data: fnApp),
        );
      } else {
        final fnExpr = Expr.data(reducedFn);
        return FnExpr.bodyCases(
          fnExpr,
          pal: (bodyExpr) {
            return reduce(
              ctx.withBinding(Binding.mk(
                id: FnExpr.argID(fnExpr),
                name: FnExpr.argName(fnExpr),
                type: reduce(ctx, FnExpr.argType(fnExpr)),
              )),
              bodyExpr,
            );
          },
          dart: (_) => Expr.mk(impl: FnApp.exprImpl, data: fnApp),
        );
      }
    }
    return Expr.mk(impl: FnApp.exprImpl, data: fnApp);
  },
  const ID.from(id: 'be6e4c77-a9fb-4d10-92cc-338c59ec3d5b'): (Ctx ctx, Object fnApp) {
    return Option.cases(
      typeCheck(ctx, FnApp.fn(fnApp)),
      none: () => Option.mk(),
      some: (fnTypeExpr) {
        if ({Literal.type, Construct.type}.contains(Expr.dataType(fnTypeExpr))) {
          return Option.cases(
            typeCheck(ctx, FnApp.arg(fnApp)),
            none: () => Option.mk(),
            some: (argType) {
              // TODO: weird logic here around Fn arg types are exprs, so fnTypeExpr argtype member is??
              final argAssignable = assignable(
                ctx,
                Type.exprMemberEquals(ctx, fnTypeExpr, [Fn.argTypeID]),
                argType,
              );
              if (argAssignable) {
                final argID = Literal.getValue(
                  Expr.data(
                    Type.exprMemberEquals(ctx, fnTypeExpr, [Fn.argIDID]),
                  ),
                ) as ID;
                ctx = ctx.withBinding(
                  Binding.mk(
                    id: argID,
                    type: argType,
                    name: argID.label ?? '$argID',
                    reducedValue: reduce(ctx, FnApp.arg(fnApp)),
                  ),
                );
                return Option.mk(reduce(
                  ctx,
                  Literal.getValue(
                    Expr.data(Type.exprMemberEquals(ctx, fnTypeExpr, [Fn.returnTypeID])),
                  ),
                ));
              } else {
                return Option.mk();
              }
            },
          );
        }
        throw Exception('type check fn app where fnType isn\'t literal not yet implemented!');
      },
    );
  },
  const ID.from(id: '738cb307-4b48-4bf2-907b-e06e1e42a49a'): (Ctx ctx, Object arg) {
    final exprFreeVars = freeVars(ctx, Expr.mk(impl: FnExpr.exprImpl, data: arg));
    return Fn.mk(
      argName: FnExpr.argName(arg),
      argID: FnExpr.argID(arg),
      body: UnionTag.mk(
        UnionTag.tag(FnExpr.body(arg)) == FnExpr.palID ? Fn.palID : Fn.dartID,
        UnionTag.value(FnExpr.body(arg)),
      ),
      closure: List.mk([
        for (final freeVar in exprFreeVars)
          ...Option.cases(ctx.getBinding(freeVar), some: (b) => [b], none: () => const [])
      ]),
    );
  },
  const ID.from(id: 'a814d41c-2b9b-49a0-afc2-9c6c25e47468'): (Ctx ctx, Object fnData) =>
      Expr.mk(impl: FnExpr.exprImpl, data: fnData),
  const ID.from(id: '916ccdd7-75de-4c37-b728-a318b101aff7'): (Ctx ctx, Object fn) {
    return Option.cases(
      typeCheck(ctx, FnExpr.argType(fn)),
      none: () => Option.mk(),
      some: (argTypeType) {
        if (!assignable(ctx, Type.lit(Type.type), argTypeType)) {
          return Option.mk();
        }
        final argType = reduce(ctx, FnExpr.argType(fn));
        ctx = ctx.withBinding(
          Binding.mk(
            id: FnExpr.argID(fn),
            type: argType,
            name: FnExpr.argName(fn),
          ),
        );
        return Option.cases(
          FnExpr.returnType(fn),
          none: () => FnExpr.bodyCases(
            fn,
            dart: (_) => throw Exception('dart Fn w no declared return type not allowed!'),
            pal: (body) => Option.cases(
              typeCheck(ctx, body),
              none: () => Option.mk(),
              some: (bodyType) {
                if (Expr.dataType(argType) != Literal.type) {
                  // TODO: would like to reduce but causes loop w TypeProperty.mkExpr rn
                  return Option.mk(Fn.typeExpr(
                    argID: FnExpr.argID(fn),
                    argType: argType,
                    returnType: bodyType,
                  ));
                } else {
                  return Option.mk(
                    Literal.mk(
                      Type.type,
                      Fn.type(
                        argID: FnExpr.argID(fn),
                        argType: Literal.getValue(Expr.data(argType)),
                        returnType: bodyType,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          some: (returnTypeExpr) => Option.cases(
            typeCheck(ctx, returnTypeExpr),
            none: () => Option.mk(),
            some: (returnTypeType) {
              if (!assignable(ctx, Type.lit(Type.type), returnTypeType)) {
                return Option.mk();
              }
              final returnType = reduce(ctx, returnTypeExpr);
              return FnExpr.bodyCases(
                fn,
                pal: (body) => Option.cases(
                  typeCheck(ctx, body),
                  none: () => Option.mk(),
                  some: (bodyType) {
                    if (!assignable(ctx, returnType, bodyType)) return Option.mk();
                    // TODO: weird logic here around expr wrapping in FnValue.types?
                    if (Expr.dataType(argType) != Literal.type) {
                      // TODO: would like to reduce but causes loop w TypeProperty.mkExpr rn
                      return Option.mk(Fn.typeExpr(
                        argID: FnExpr.argID(fn),
                        argType: argType,
                        returnType: returnType,
                      ));
                    } else {
                      return Option.mk(
                        Literal.mk(
                          Type.type,
                          Fn.type(
                            argID: FnExpr.argID(fn),
                            argType: Literal.getValue(Expr.data(argType)),
                            returnType: returnType,
                          ),
                        ),
                      );
                    }
                  },
                ),
                // TODO: typecheck arg & return type exprs
                dart: (_) => Option.mk(reduce(
                  ctx,
                  Fn.typeExpr(
                    argID: FnExpr.argID(fn),
                    argType: argType,
                    returnType: returnType,
                  ),
                )),
              );
            },
          ),
        );
      },
    );
  },
  const ID.from(id: '19e1d36f-81f1-4c8e-bfc5-69cbde60bd8a'): (ctx, arg) => Dict({
        for (final entry in List.iterate((arg as Dict)[Map.mkEntriesID].unwrap!))
          eval(ctx, List.iterate(entry).first): eval(ctx, List.iterate(entry).skip(1).first)
      }),
  const ID.from(id: '7fa732c0-a61d-4e43-94e4-c4fafe04d254'): (ctx, arg) {
    throw Exception('reduce map expr not yet implemented!');
  },
  const ID.from(id: '7f2c7445-867b-4d44-afae-040ee700bff6'): (ctx, arg) {
    final keyType = (arg as Dict)[Map.mkKeyID].unwrap!;
    final valueType = arg[Map.mkValueID].unwrap!;

    for (final entry in List.iterate(arg[Map.mkEntriesID].unwrap!)) {
      if (typeCheck(ctx, List.iterate(entry).first) != Option.mk(keyType)) {
        return Option.mk();
      }
      if (typeCheck(ctx, List.iterate(entry).skip(1).first) != Option.mk(valueType)) {
        return Option.mk();
      }
    }
    return Option.mk(Map.type(keyType, valueType));
  },
  const ID.from(id: 'd755250f-c583-4d96-84da-f4c0a6bdd823'): (Ctx ctx, Object arg) => List.mk(
        [...List.iterate((arg as Dict)[List.mkValuesID].unwrap!).map((expr) => eval(ctx, expr))],
      ),
  const ID.from(id: '6600af92-b24d-4e65-8b78-35d9ba9d8b12'): (Ctx ctx, Object arg) {
    bool nonLit = false;
    final reducedSubExprs = <Object>[];
    for (final subExpr in List.iterate((arg as Dict)[List.mkValuesID].unwrap!)) {
      final reduced = reduce(ctx, subExpr);
      if (Expr.dataType(reduced) != Literal.type) nonLit = true;
      reducedSubExprs.add(reduced);
    }
    if (nonLit) return List.mkExpr(arg[List.mkTypeID].unwrap!, reducedSubExprs);
    return Literal.mk(
      List.type(arg[List.mkTypeID].unwrap!),
      List.mk([...reducedSubExprs.map(Expr.data).map(Literal.getValue)]),
    );
  },
  const ID.from(id: '6c67f06e-cbe0-4a46-a7e4-c04ee77eb3e1'): (Ctx ctx, Object arg) {
    final listValueType = (arg as Dict)[List.mkTypeID].unwrap!;
    for (final value in List.iterate(List.mkExprValues(arg))) {
      final valueType = typeCheck(ctx, value);
      if (!Option.isPresent(valueType)) return Option.mk();
      if (!assignable(ctx, Type.lit(listValueType), Option.unwrap(valueType))) {
        return Option.mk();
      }
    }
    return Option.mk(Type.lit(List.type(listValueType)));
  },
  const ID.from(id: '85c45fc9-c594-43b9-b126-739713a1c5e8'): (ctx, implDef) => List.mk([
        Union.mk(
          ModuleDef.type,
          ValueDef.mk(
            id: ImplDef.bindingID(implDef),
            name:
                'impl of ${ImplDef.implemented(implDef).label ?? ImplDef.implemented(implDef).id}',
            value: ImplDef.definition(implDef),
          ),
        ),
      ]),
  const ID.from(id: '524fbec2-aa08-43bd-b8b3-ffe89d89d7aa'): (ctx, ifaceDef) {
    return List.mk([
      Union.mk(
        ModuleDef.type,
        ValueDef.mk(
          id: InterfaceDef.id(ifaceDef),
          name: TypeTree.name(InterfaceDef.tree(ifaceDef)),
          value: Literal.mk(InterfaceDef.type, ifaceDef),
        ),
      ),
      Union.mk(
        ModuleDef.type,
        TypeDef.mkDef(
          TypeDef.mk(
            InterfaceDef.tree(ifaceDef),
            id: InterfaceDef.innerTypeDefID(InterfaceDef.id(ifaceDef)),
          ),
        ),
      ),
    ]);
  },
  const ID.from(id: '01415159-a7a9-42ce-a749-0c6428775166'): (ctx, typeDef) {
    return List.mk([
      Union.mk(
        ModuleDef.type,
        ValueDef.mk(
          id: TypeDef.id(typeDef),
          name: TypeTree.name(TypeDef.tree(typeDef)),
          value: Literal.mk(TypeDef.type, typeDef),
        ),
      ),
      Union.mk(
        ModuleDef.type,
        ValueDef.mk(
          id: TypeDef.id(typeDef).append(TypeDef._typeLitID),
          name: TypeTree.name(TypeDef.tree(typeDef)),
          value: Type.lit(TypeDef.asType(typeDef)),
        ),
      ),
    ]);
  },
  const ID.from(id: '4a5ff699-216d-49c3-8fea-7687cb90a35b'): (ctx, arg) {
    Object? lazyType;
    Object? lazyValue;

    final bindingID = (arg as Dict)[ValueDef.IDID].unwrap! as ID;
    final expr = arg[ValueDef.valueID].unwrap!;
    computeType(Ctx ctx) {
      lazyType ??= Option.cases(
        typeCheck(updateVisited(ctx, bindingID), expr),
        some: (checkedType) => checkedType,
        none: () => throw const MyException(),
      );
      if (Expr.dataType(lazyType!) != Literal.type) throw const MyException();
      Option.cases(arg[ValueDef.expectedTypeID].unwrap!, none: () {}, some: (expectedType) {
        if (!assignable(ctx, expectedType, lazyType!)) throw const MyException();
      });
      return lazyType!;
    }

    computeValue(Ctx ctx) {
      computeType(ctx);
      lazyValue ??= eval(updateVisited(ctx, bindingID), expr);
      return lazyValue!;
    }

    return List.mk([
      Union.mk(
        Binding.type,
        Binding.mkLazy(
          id: bindingID,
          name: arg[ValueDef.nameID].unwrap! as String,
          type: computeType,
          value: computeValue,
        ),
      ),
    ]);
  },
};
