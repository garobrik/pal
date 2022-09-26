import 'dart:core' as dart;
import 'dart:core';
import 'package:ctx/ctx.dart';
import 'package:reified_lenses/reified_lenses.dart' as reified;
import 'package:uuid/uuid.dart';

typedef Dict = reified.Dict<Object, Object>;
typedef DartList = dart.List<Object>;
typedef Vec = reified.Vec<Object>;
typedef Set = reified.CSet<Object>;

class ID extends Comparable<ID> {
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
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    nameID: TypeTree.mk('name', Literal.mk(Type.type, text)),
    definitionsID: TypeTree.mk('definitions', Literal.mk(Type.type, List.type(ModuleDef.type))),
  });
  static final type = TypeDef.asType(def);

  static Object mk({ID? id, required String name, required DartList definitions}) =>
      Dict({IDID: id ?? ID(), nameID: name, definitionsID: List.mk(definitions)});

  static Object load(Ctx evalCtx, Object module) {
    Iterable<Object> expandDef(Object moduleDef) {
      final list = eval(
        evalCtx,
        FnApp.mk(
          RecordAccess.mk(
            target: RecordAccess.mk(
              target: Literal.mk(ModuleDef.type, moduleDef),
              member: ModuleDef.implID,
            ),
            member: ModuleDef.bindingsID,
          ),
          RecordAccess.mk(target: Literal.mk(ModuleDef.type, moduleDef), member: ModuleDef.dataID),
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
    final resultCtx = bindings.fold<Ctx>(evalCtx, (ctx, binding) => ctx.withBinding(binding));
    try {
      for (final binding in bindings) {
        Binding.valueType(resultCtx, binding);
      }
    } on MyException {
      return Option.mk();
    }
    return Option.mk(resultCtx);
  }

  static final bindingOrDef = Union.type([ModuleDef.type, Binding.type]);
}

abstract class ModuleDef extends InterfaceDef {
  static final dataTypeID = ID('dataType');
  static final bindingsID = ID('bindings');
  static final interfaceDef = InterfaceDef.record('ModuleDef', {
    dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    bindingsID: TypeTree.mk(
      'bindings',
      Fn.typeExpr(
        argType: Var.mk(dataTypeID),
        returnType: Literal.mk(Type.type, List.type(Module.bindingOrDef)),
      ),
    ),
  });

  static Object mkImpl({
    required Object dataType,
    required Object bindings,
    ID? id,
  }) =>
      ImplDef.mk(
        implemented: InterfaceDef.id(interfaceDef),
        members: Dict({
          dataTypeID: Literal.mk(Type.type, dataType),
          bindingsID: bindings,
        }),
      );

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final typeDefID = ID('ModuleDef');
  static final typeDef = TypeDef.record(
    'ModuleDef',
    {
      implID: TypeTree.mk('impl', Literal.mk(Type.type, InterfaceDef.implType(interfaceDef))),
      dataID: TypeTree.mk(
        'data',
        RecordAccess.mk(
          target: Var.mk(implID),
          member: dataTypeID,
        ),
      ),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static Object mk({required Object implDef, required Object data}) =>
      Dict({implID: ImplDef.asImpl(Ctx.empty, ModuleDef.interfaceDef, implDef), dataID: data});

  static Object impl(Object moduleDef) => (moduleDef as Dict)[implID].unwrap!;
  static Object dataType(Object moduleDef) => (impl(moduleDef) as Dict)[dataTypeID].unwrap!;
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

  static Object mk({required ID id, required String name, required Object value}) =>
      ModuleDef.mk(implDef: moduleDefImplDef, data: Dict({IDID: id, nameID: name, valueID: value}));

  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: TypeDef.asType(typeDef),
    bindings: Fn.dart(
      argName: 'valueDef',
      argType: TypeDef.asType(typeDef),
      returnType: List.type(Module.bindingOrDef),
      body: (ctx, arg) {
        Object? lazyType;
        Object? lazyValue;

        final bindingID = (arg as Dict)[IDID].unwrap! as ID;
        final expr = arg[valueID].unwrap!;
        computeType(Ctx ctx) {
          lazyType ??= Option.cases(
            typeCheck(updateVisited(ctx, bindingID), expr),
            some: (checkedType) => checkedType,
            none: () => throw const MyException(),
          );
          if (Expr.dataType(lazyType!) != Literal.type) throw const MyException();
          return lazyType!;
        }

        computeValue(Ctx ctx) {
          computeType(ctx);
          lazyValue ??= eval(updateVisited(ctx, bindingID), expr);
          return lazyValue!;
        }

        return List.mk([
          Union.mk(
            [ModuleDef.type, Binding.type],
            Binding.type,
            Binding.mkLazy(
              id: bindingID,
              name: arg[nameID].unwrap! as String,
              type: computeType,
              value: computeValue,
            ),
          ),
        ]);
      },
    ),
    id: ID('ValueDefImpl'),
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

  static Object asType(Object typeDef, {DartList properties = const []}) => Type.mk(
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
    bindings: Fn.dart(
      argName: 'typeDef',
      argType: type,
      returnType: List.type(Module.bindingOrDef),
      body: (ctx, typeDef) {
        return List.mk([
          Union.mk(
            [ModuleDef.type, Binding.type],
            ModuleDef.type,
            ValueDef.mk(
              id: TypeDef.id(typeDef),
              name: TypeTree.name(TypeDef.tree(typeDef)),
              value: Literal.mk(TypeDef.type, typeDef),
            ),
          ),
          Union.mk(
            [ModuleDef.type, Binding.type],
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
      IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
      pathID: TypeTree.mk('path', Literal.mk(Type.type, List.type(ID.type))),
      propertiesID: TypeTree.mk('properties', Literal.mk(Type.type, List.type(TypeProperty.type))),
    },
    id: _typeID,
  );
  static final type = Type.mk(_typeID);

  static Dict mk(
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
    Object? properties,
  }) =>
      Construct.mk(
        Type.type,
        Dict({
          IDID: Literal.mk(ID.type, id),
          pathID: path ?? Literal.mk(List.type(ID.type), List.mk(const [])),
          propertiesID: properties ?? Literal.mk(List.type(TypeProperty.type), List.mk(const [])),
        }),
      );

  static ID id(Object type) => (type as Dict)[IDID].unwrap! as ID;
  static Object path(Object type) => (type as Dict)[pathID].unwrap!;
  static Object properties(Object type) => (type as Dict)[propertiesID].unwrap!;
  static Object memberEquals(Ctx ctx, Object type, dart.List<ID> path) {
    return List.iterate(properties(type)).expand<Object>((property) {
      if (TypeProperty.dataType(property) != MemberHas.type) return [];
      final memberHas = TypeProperty.data(property);
      if (MemberHas.path(memberHas) != List.mk(path)) return [];
      final memberHasProp = MemberHas.property(memberHas);
      if (TypeProperty.dataType(memberHasProp) != Equals.type) return [];
      return [Equals.equalTo(TypeProperty.data(memberHasProp))];
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
  static final interfaceID = ID('interface');
  static final interfaceDef = InterfaceDef.record(
    'TypePropertyImpl',
    {
      dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    },
    id: interfaceID,
  );
  static final implType = InterfaceDef.implType(interfaceDef);

  static Dict mkImpl({
    ID? id,
    required Object dataType,
  }) =>
      ImplDef.mk(
        id: id,
        implemented: interfaceID,
        members: Dict({dataTypeID: Literal.mk(Type.type, dataType)}),
      );

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final typeDef = TypeDef.record('TypeProperty', {
    implID: TypeTree.mk('impl', Literal.mk(Type.type, implType)),
    dataID: TypeTree.mk(
      'data',
      RecordAccess.mk(
        target: Var.mk(implID),
        member: dataTypeID,
      ),
    ),
  });
  static final type = TypeDef.asType(typeDef);

  static Dict mk(Object impl, Object data) => Dict({implID: impl, dataID: data});

  static Object mkExpr(Object implDef, Object data) {
    final impl = ImplDef.asImpl(Ctx.empty, interfaceDef, implDef);
    return Construct.mk(type, Dict({implID: Literal.mk(implType, impl), dataID: data}));
  }

  static Object impl(Object typeProperty) => (typeProperty as Dict)[implID].unwrap!;
  static Object data(Object typeProperty) => (typeProperty as Dict)[dataID].unwrap!;
  static Object dataType(Object typeProperty) => (impl(typeProperty) as Dict)[dataTypeID].unwrap!;
}

abstract class Equals extends TypeProperty {
  static final dataTypeID = ID('dataType');
  static final equalToID = ID('equalTo');

  static final typeDefID = ID('Equals');
  static final typeDef = TypeDef.record(
    'Equals',
    {
      dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
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
      pathID: TypeTree.mk('path', Literal.mk(Type.type, List.type(ID.type))),
      propertyID: TypeTree.mk('property', Literal.mk(Type.type, TypeProperty.type)),
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

  static Object mkEqualsExpr(Object path, Object type, Object equalTo) =>
      mkExpr(path: path, property: Equals.mkExpr(type, equalTo));

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

  static Iterable<Object> dataBindings(Object typeDef, Object dataTree) {
    return foldData(
      [],
      TypeDef.tree(typeDef),
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
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    treeID: TypeTree.mk('tree', Literal.mk(Type.type, TypeTree.type)),
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
    bindings: Fn.dart(
      argName: 'interfaceDef',
      argType: type,
      returnType: List.type(Module.bindingOrDef),
      body: (ctx, ifaceDef) {
        return List.mk([
          Union.mk(
            [ModuleDef.type, Binding.type],
            ModuleDef.type,
            ValueDef.mk(
              id: InterfaceDef.id(ifaceDef),
              name: TypeTree.name(InterfaceDef.tree(ifaceDef)),
              value: Literal.mk(InterfaceDef.type, ifaceDef),
            ),
          ),
          Union.mk(
            [ModuleDef.type, Binding.type],
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
    ),
    id: ID('InterfaceDefImpl'),
  );

  static Object mkDef(Object def) => ModuleDef.mk(implDef: moduleDefImplDef, data: def);
  static Object implType(Object interfaceDef, [DartList properties = const []]) =>
      Type.mk(innerTypeDefID(InterfaceDef.id(interfaceDef)), properties: properties);
  static Object implTypeByID(ID interfaceID) => Type.mk(innerTypeDefID(interfaceID));
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
  static final type = TypeDef.asType(def);

  static Dict mk({ID? id, required ID implemented, required Object members}) =>
      Dict({IDID: id ?? ID(), implementedID: implemented, membersID: members});

  static Object members(Object implDef) => (implDef as Dict)[membersID].unwrap!;

  static final moduleDefImplDef = ModuleDef.mkImpl(
    dataType: type,
    bindings: Fn.dart(
      argName: 'typeDef',
      argType: type,
      returnType: List.type(Module.bindingOrDef),
      body: (ctx, implDef) {
        return List.mk([
          Union.mk(
            [ModuleDef.type, Binding.type],
            ModuleDef.type,
            ValueDef.mk(
              id: ImplDef.implemented(implDef).append(ImplDef.id(implDef)),
              name: 'impl',
              value: Construct.mk(
                Type.mk(InterfaceDef.innerTypeDefID(ImplDef.implemented(implDef))),
                ImplDef.members(implDef),
              ),
            ),
          ),
        ]);
      },
    ),
    id: ID('ImplDefImpl'),
  );

  static Object mkDef(Object def) => ModuleDef.mk(implDef: moduleDefImplDef, data: def);

  static Object asImpl(Ctx ctx, Object interfaceDef, Object implDef) {
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

    return recurse(InterfaceDef.tree(interfaceDef), ImplDef.members(implDef));
  }

  static ID id(Object impl) => (impl as Dict)[IDID].unwrap! as ID;
  static ID implemented(Object impl) => (impl as Dict)[implementedID].unwrap! as ID;
}

abstract class Union {
  static final possibleTypesID = ID('dataType');
  static final thisTypeID = ID('thisType');
  static final valueID = ID('value');

  static final def = TypeDef.record('Union', {
    possibleTypesID: TypeTree.mk('possibleTypes', Literal.mk(Type.type, List.type(Type.type))),
    thisTypeID: TypeTree.mk('thisType', Literal.mk(Type.type, Type.type)),
    valueID: TypeTree.mk('value', Var.mk(thisTypeID)),
  });

  static Object mk(DartList possibleTypes, Object thisType, Object value) => Dict({
        possibleTypesID: List.mk(possibleTypes),
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

abstract class Option {
  static final dataTypeID = ID('dataType');
  static final valueID = ID('value');
  static final someID = ID('some');
  static final noneID = ID('none');

  static final typeDefID = ID('Option');
  static final def = TypeDef.record(
    'Option',
    {
      dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
      valueID: TypeTree.union('value', {
        someID: TypeTree.mk('some', Var.mk(dataTypeID)),
        noneID: TypeTree.unit('none'),
      }),
    },
    id: typeDefID,
  );

  static Object type(Object dataType) => Type.mk(typeDefID, properties: [
        MemberHas.mk(path: [dataTypeID], property: Equals.mk(Type.type, dataType)),
      ]);

  static Object typeExpr(Object dataType) => Type.mkExpr(Type.id(type(unit)),
      properties: List.mkExpr(TypeProperty.type, [
        MemberHas.mkExpr(
          path: Literal.mk(List.type(ID.type), List.mk([dataTypeID])),
          property: Equals.mkExpr(Literal.mk(Type.type, Type.type), dataType),
        ),
      ]));

  static T cases<T>(
    Object option, {
    required T Function(Object) some,
    required T Function() none,
  }) {
    final value = (option as Dict)[valueID].unwrap!;
    return UnionTag.tag(value) == someID ? some(UnionTag.value(value)) : none();
  }

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
  static final typeCheckID = ID('typeCheck');
  static final reduceID = ID('reduce');
  static final evalExprID = ID('evalExpr');

  static final interfaceID = ID('Expr');
  static final interfaceDef = InterfaceDef.record(
    'ExprInterface',
    {
      dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
      typeCheckID: TypeTree.mk(
        'typeCheck',
        Fn.typeExpr(
          argType: Var.mk(dataTypeID),
          returnType: Literal.mk(Type.type, Option.type(typeExprType)),
        ),
      ),
      reduceID: TypeTree.mk(
        'reduce',
        Fn.typeExpr(
          argType: Var.mk(dataTypeID),
          returnType: Literal.mk(Type.type, Expr.type),
        ),
      ),
      evalExprID: TypeTree.mk(
        'eval',
        Fn.typeExpr(argType: Var.mk(dataTypeID), returnType: Literal.mk(Type.type, Any.type)),
      )
    },
    id: interfaceID,
  );
  static final implType = InterfaceDef.implTypeByID(interfaceID);

  static Object mkImplDef({
    required Object dataType,
    required Object typeCheck,
    required Object reduce,
    required Object eval,
    ID? id,
  }) =>
      ImplDef.mk(
        id: id ?? ID(),
        implemented: interfaceID,
        members: Dict({
          dataTypeID: Literal.mk(Type.type, dataType),
          typeCheckID: typeCheck,
          reduceID: reduce,
          evalExprID: eval,
        }),
      );

  static Object mkImpl({
    required Object dataType,
    required Object typeCheck,
    required Object reduce,
    required Object eval,
  }) =>
      Dict({dataTypeID: dataType, typeCheckID: typeCheck, reduceID: reduce, evalExprID: eval});

  static Object dataType(Object expr) => (impl(expr) as Dict)[dataTypeID].unwrap!;
  static Object evalExpr(Object expr) => (impl(expr) as Dict)[evalExprID].unwrap!;

  static final implID = ID('impl');
  static final dataID = ID('data');
  static final _defID = ID('ExprData');
  static final def = TypeDef.record(
    'Expr',
    {
      implID: TypeTree.mk('impl', Literal.mk(Type.type, implType)),
      dataID: TypeTree.mk(
        'data',
        RecordAccess.mk(
          target: Var.mk(implID),
          member: Expr.dataTypeID,
        ),
      ),
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

  static Object typeCheckFn = Fn.from(
    argName: 'expr',
    argType: Expr.type,
    returnType: Option.type(typeExprType),
    body: (arg) => FnApp.mk(
      RecordAccess.mk(
        target: RecordAccess.mk(target: arg, member: implID),
        member: typeCheckID,
      ),
      RecordAccess.mk(target: arg, member: dataID),
    ),
  );

  static Object reduceFn = Fn.from(
    argName: 'expr',
    argType: Expr.type,
    returnType: Option.type(Expr.type),
    body: (arg) => FnApp.mk(
      RecordAccess.mk(
        target: RecordAccess.mk(target: arg, member: implID),
        member: reduceID,
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
  static final itemsID = ID('items');
  static final typeDefID = ID('List');
  static final def = TypeDef.record(
    'List',
    {
      typeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
      itemsID: TypeTree.unit('items'),
    },
    id: typeDefID,
  );

  static final mkExprTypeDefID = ID('mkExpr');
  static final mkTypeID = ID('mkType');
  static final mkValuesID = ID('mkValues');
  static final exprTypeDef = TypeDef.record(
    'MkList',
    {
      mkTypeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
      mkValuesID: TypeTree.mk('mkValues', Literal.mk(Type.type, List.type(Expr.type))),
    },
    id: mkExprTypeDefID,
  );
  static final _typeFn = Fn.dart(
    argName: 'mkListData',
    argType: TypeDef.asType(exprTypeDef),
    returnType: Option.type(typeExprType),
    // TODO: do right
    body: (ctx, arg) =>
        Option.mk(Literal.mk(Type.type, List.type((arg as Dict)[mkTypeID].unwrap!))),
  );
  static final _reduceFn = Fn.dart(
    argName: 'mkListData',
    argType: TypeDef.asType(exprTypeDef),
    returnType: Expr.type,
    body: (ctx, arg) {
      bool nonLit = false;
      final reducedSubExprs = <Object>[];
      for (final subExpr in iterate((arg as Dict)[mkValuesID].unwrap!)) {
        final reduced = reduce(ctx, subExpr);
        if (Expr.dataType(reduced) != Literal.type) nonLit = true;
        reducedSubExprs.add(reduced);
      }
      if (nonLit) return List.mkExpr(arg[mkTypeID].unwrap!, reducedSubExprs);
      return Literal.mk(
        List.type(arg[mkTypeID].unwrap!),
        List.mk([...reducedSubExprs.map(Expr.data).map(Literal.getValue)]),
      );
    },
  );
  static final _evalFn = Fn.dart(
    argName: 'mkListData',
    argType: TypeDef.asType(exprTypeDef),
    returnType: List.type(Any.type),
    body: (ctx, arg) =>
        List.mk([...iterate((arg as Dict)[mkValuesID].unwrap!).map((expr) => eval(ctx, expr))]),
  );
  static final mkExprImplDef = Expr.mkImplDef(
    dataType: TypeDef.asType(exprTypeDef),
    typeCheck: _typeFn,
    reduce: _reduceFn,
    eval: _evalFn,
  );
  static final mkExprImpl = Expr.mkImpl(
    dataType: TypeDef.asType(exprTypeDef),
    typeCheck: Expr.data(_typeFn),
    reduce: Expr.data(_reduceFn),
    eval: Expr.data(_evalFn),
  );

  static Object type(Object type) => Type.mk(typeDefID, properties: [
        MemberHas.mk(path: [typeID], property: Equals.mk(Type.type, type)),
      ]);

  static Object mk(DartList values) => Dict({itemsID: Vec(values)});

  static Object mkExpr(Object type, DartList values) => Expr.mk(
        impl: mkExprImpl,
        data: Dict({mkTypeID: type, mkValuesID: List.mk(values)}),
      );

  static Vec _items(Object list) => (list as Dict)[itemsID].unwrap! as Vec;
  static Iterable<Object> iterate(Object list) => _items(list);
  static Object _withList(Object list, DartList Function(Iterable<Object>) f) =>
      List.mk(f(_items(list)));
  static Object add(Object list, Object item) => _withList(list, (i) => [...i, item]);
  static Object tail(Object list) => _withList(list, (i) => [...i.skip(1)]);
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

  static final mkExprImplDef = Expr.mkImplDef(
    dataType: List.type(Expr.type),
    typeCheck: Fn.dart(
      argName: 'mkMapData',
      argType: mkType,
      returnType: Option.type(typeExprType),
      body: (ctx, arg) {
        final keyType = (arg as Dict)[mkKeyID].unwrap!;
        final valueType = arg[mkValueID].unwrap!;

        for (final entry in List.iterate(arg[mkEntriesID].unwrap!)) {
          if (typeCheck(ctx, List.iterate(entry).first) != Option.mk(keyType)) {
            return Option.mk();
          }
          if (typeCheck(ctx, List.iterate(entry).skip(1).first) != Option.mk(valueType)) {
            return Option.mk();
          }
        }
        return Option.mk(Map.type(keyType, valueType));
      },
    ),
    reduce: Fn.dart(
      argName: 'mkMapData',
      argType: mkType,
      returnType: Expr.type,
      body: (ctx, arg) {
        throw Exception('reduce map expr not yet implemented!');
      },
    ),
    eval: Fn.dart(
      argName: 'mkMapData',
      argType: mkType,
      returnType: List.type(Any.type),
      body: (ctx, arg) => Dict({
        for (final entry in List.iterate((arg as Dict)[mkEntriesID].unwrap!))
          eval(ctx, List.iterate(entry).first): eval(ctx, List.iterate(entry).skip(1).first)
      }),
    ),
  );
  static Object mkExpr(Type key, Type value, Object entries) => Expr.mk(
        impl: ImplDef.asImpl(Ctx.empty, Expr.interfaceDef, mkExprImplDef),
        data: Dict({mkKeyID: key, mkValueID: value, mkEntriesID: entries}),
      );
}

abstract class Any {
  static final typeID = ID('type');
  static final valueID = ID('value');

  static final anyTypeID = ID('Any');
  static final def = TypeDef.record(
    'Any',
    {
      typeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
      valueID: TypeTree.mk('valueID', Var.mk(typeID)),
    },
    id: anyTypeID,
  );
  static final type = Type.mk(anyTypeID);

  static Object getType(Object any) => (any as Dict)[typeID].unwrap!;
  static Object getValue(Object any) => (any as Dict)[valueID].unwrap!;

  static Object mk(Object type, Object value) => Dict({typeID: type, valueID: value});
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
final typeExprType = Expr.type;

abstract class Fn extends Expr {
  static final argIDID = ID('argID');
  static final argNameID = ID('argName');
  static final fnTypeID = ID('fnType');
  static final argTypeID = ID('argType');
  static final returnTypeID = ID('returnType');
  static final bodyID = ID('body');
  static final palID = ID('pal');
  static final dartID = ID('dart');

  static final typeDefID = ID('Fn');
  static final typeDef = TypeDef.record(
    'Fn',
    {
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
    },
    id: typeDefID,
  );

  static final exprImplID = ID('FnExprImpl');
  static final typeFnData = Fn.mkData(
    argName: 'fnData',
    argType: Type.mk(typeDefID),
    returnType: Option.type(typeExprType),
    body: UnionTag.mk(
      dartID,
      (Ctx ctx, Object fn) {
        return Fn.bodyCases(
          fn,
          pal: (body) {
            final argID = Fn.argID(fn);
            final argType = Fn.argType(fn);
            final bodyType = typeCheck(
              ctx.withBinding(
                Binding.mk(id: argID, type: Literal.mk(Type.type, argType), name: Fn.argName(fn)),
              ),
              body,
            );
            return Option.cases(
              bodyType,
              some: (bodyType) {
                if (assignable(ctx, Literal.mk(Type.type, returnType(fn)), bodyType)) {
                  return Option.mk(
                    Literal.mk(Type.type, Fn.type(argType: argType, returnType: returnType(fn))),
                  );
                } else {
                  return Option.mk();
                }
              },
              none: () => Option.mk(),
            );
          },
          dart: (_) => Option.mk(Literal.mk(Type.type, _fnToType(fn))),
        );
      },
    ),
  );
  static final typeFn = Expr.mk(impl: exprImpl, data: typeFnData);
  static final reduceFnData = Fn.mkData(
    argName: 'fnData',
    argType: Type.mk(typeDefID),
    returnType: Expr.type,
    body: UnionTag.mk(
      dartID,
      (Ctx ctx, Object fnData) => Expr.mk(impl: exprImpl, data: fnData),
    ),
  );
  static final reduceFn = Expr.mk(impl: exprImpl, data: reduceFnData);
  static final evalFnData = Fn.mkData(
    argName: 'fnData',
    argType: Type.mk(typeDefID),
    returnType: Any.type,
    body: UnionTag.mk(dartID, (Ctx ctx, Object arg) => arg),
  );
  static final evalFn = Expr.mk(impl: exprImpl, data: evalFnData);

  static final exprImplDef = Expr.mkImplDef(
    id: exprImplID,
    dataType: Type.mk(typeDefID),
    typeCheck: typeFn,
    reduce: reduceFn,
    eval: evalFn,
  );

  static final Object exprImpl = Expr.mkImpl(
    dataType: Type.mk(typeDefID),
    typeCheck: typeFnData,
    reduce: reduceFnData,
    eval: evalFnData,
  );

  static Object type({required Object argType, required Object returnType}) =>
      Type.mk(typeDefID, properties: [
        MemberHas.mkEquals([fnTypeID, argTypeID], Type.type, argType),
        MemberHas.mkEquals([fnTypeID, returnTypeID], Type.type, returnType),
      ]);

  static Object typeExpr({required Object argType, required Object returnType}) => Type.mkExpr(
        typeDefID,
        properties: List.mkExpr(TypeProperty.type, [
          MemberHas.mkExpr(
            path: Literal.mk(List.type(ID.type), List.mk([fnTypeID, argTypeID])),
            property: Equals.mkExpr(Literal.mk(Type.type, Type.type), argType),
          ),
          MemberHas.mkExpr(
            path: Literal.mk(List.type(ID.type), List.mk([fnTypeID, returnTypeID])),
            property: Equals.mkExpr(Literal.mk(Type.type, Type.type), returnType),
          ),
        ]),
      );

  static Object _fnToType(Object fn) => Fn.type(argType: argType(fn), returnType: returnType(fn));

  static Dict mkData({
    ID? argID,
    required String argName,
    required Object argType,
    required Object returnType,
    required Object body,
  }) =>
      Dict({
        argIDID: argID ?? ID(argName),
        argNameID: argName,
        fnTypeID: Dict({argTypeID: argType, returnTypeID: returnType}),
        bodyID: body,
      });

  static Object mk({
    ID? argID,
    required String argName,
    required Object argType,
    required Object returnType,
    required Object body,
  }) =>
      Expr.mk(
        data: mkData(
          argID: argID,
          argName: argName,
          argType: argType,
          returnType: returnType,
          body: UnionTag.mk(palID, body),
        ),
        impl: exprImpl,
      );

  static Object dart({
    ID? argID,
    required String argName,
    required Object argType,
    required Object returnType,
    required Object Function(Ctx, Object) body,
  }) =>
      Expr.mk(
        data: mkData(
          argID: argID,
          argName: argName,
          argType: argType,
          returnType: returnType,
          body: UnionTag.mk(dartID, body),
        ),
        impl: exprImpl,
      );

  static Object from({
    required String argName,
    required Object argType,
    required Object returnType,
    required Object Function(Object) body,
  }) {
    final argID = ID(argName);
    return Fn.mk(
      argID: argID,
      argName: argName,
      argType: argType,
      returnType: returnType,
      body: body(Var.mk(argID)),
    );
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

  static final typeDef = TypeDef.mk(TypeTree.record('FnApp', {
    fnID: TypeTree.mk('fn', Literal.mk(Type.type, Expr.type)),
    argID: TypeTree.mk('arg', Literal.mk(Type.type, Expr.type)),
  }));

  static final exprImplDef = Expr.mkImplDef(
    dataType: TypeDef.asType(typeDef),
    typeCheck: Fn.dart(
      argName: 'fnAppData',
      argType: TypeDef.asType(typeDef),
      returnType: Option.type(typeExprType),
      // TODO: need to eval the fn expr
      body: (ctx, fnApp) {
        final fnExpr = fn(fnApp);
        return Option.cases(
          typeCheck(ctx, fnExpr),
          none: () => Option.mk(),
          some: (fnTypeExpr) {
            if (Expr.dataType(fnTypeExpr) != Literal.type) {
              throw Exception('type check fn app where fnType isn\'t literal not yet implemented!');
            }
            final fnType = Literal.getValue(Expr.data(fnTypeExpr));
            return Option.cases(
              typeCheck(ctx, arg(fnApp)),
              none: () => Option.mk(),
              some: (argType) {
                final argAssignable = assignable(
                  ctx,
                  Literal.mk(
                    Type.type,
                    Type.memberEquals(ctx, fnType, [Fn.fnTypeID, Fn.argTypeID]),
                  ),
                  argType,
                );
                if (argAssignable) {
                  return Option.mk(Literal.mk(
                    Type.type,
                    Type.memberEquals(ctx, fnType, [Fn.fnTypeID, Fn.returnTypeID]),
                  ));
                } else {
                  return Option.mk();
                }
              },
            );
          },
        );
      },
    ),
    reduce: Fn.dart(
      argName: 'fnAppData',
      argType: TypeDef.asType(typeDef),
      returnType: Expr.type,
      body: (ctx, arg) => throw Exception('reduce not implemented for FnApp!'),
    ),
    eval: Fn.dart(
      argName: 'fnAppData',
      argType: TypeDef.asType(typeDef),
      returnType: Any.type,
      body: (ctx, data) {
        final fn = eval(ctx, FnApp.fn(data));
        final arg = eval(ctx, FnApp.arg(data));
        return Fn.bodyCases(
          fn,
          pal: (body) => eval(
            ctx.withBinding(Binding.mk(
              id: Fn.argID(fn),
              // TODO: types shouldn't be necessary for runtime bindings!
              // type: Literal.mk(Type.type, eval(ctx, Fn.argType(fn))),
              type: Literal.mk(Type.type, Fn.argType(fn)),
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

  static Object mk(Object fn, Object arg) => Expr.mk(
        data: Dict({fnID: fn, argID: arg}),
        impl: ImplDef.asImpl(Ctx.empty, Expr.interfaceDef, exprImplDef),
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
      dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
      treeID: TypeTree.mk('tree', Literal.mk(Type.type, Any.type)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final _typeFn = Fn.dart(
    argName: 'constructData',
    argType: type,
    returnType: Option.type(typeExprType),
    body: (ctx, arg) {
      final typeDef = ctx.getType(Type.id(dataType(arg)));

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
                    if (!assignable(ctx, Literal.mk(Type.type, Type.type), checkedType)) {
                      throw const MyException();
                    }
                  },
                  none: () => throw const MyException(),
                );
                final defType = reduce(updateVisited(ctx, List.iterate(path).last as ID), leaf);
                lazyType = Option.cases(
                  typeCheck(updateVisited(ctx, List.iterate(path).last as ID), dataTree),
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
                lazyValue = reduce(updateVisited(ctx, List.iterate(path).last as ID), dataTree);
                computedProps.add(
                  MemberHas.mkEqualsExpr(
                    Literal.mk(List.type(ID.type), List.mk([...List.iterate(path)])),
                    dataType,
                    lazyValue!,
                  ),
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

      final bindings = lazyBindings(TypeDef.tree(typeDef), tree(arg), List.mk(const []));
      final typeCheckCtx = bindings.fold<Ctx>(ctx, (ctx, binding) => ctx.withBinding(binding));
      try {
        for (final binding in bindings) {
          Binding.valueType(typeCheckCtx, binding);
        }
      } on MyException {
        return Option.mk();
      }

      // add a reduce!
      return Option.mk(reduce(
        ctx,
        Type.mkExpr(
          Type.id(dataType(arg)),
          properties: List.mkExpr(TypeProperty.type, computedProps),
        ),
      ));
    },
  );

  static final _reduceFn = Fn.dart(
    argName: 'constructData',
    argType: type,
    returnType: Expr.type,
    body: (ctx, arg) {
      bool nonLit = false;
      final typeTree = TypeDef.tree(ctx.getType(Type.id(dataType(arg))));
      final exprTree = TypeTree.mapData(
        typeTree,
        tree(arg),
        (_, dataLeaf, __) {
          final reduced = reduce(ctx, dataLeaf);
          if (Expr.dataType(reduced) != Literal.type) nonLit = true;
          return reduced;
        },
      );

      if (nonLit) return Construct.mk(dataType(arg), exprTree);
      return Literal.mk(
        dataType(arg),
        TypeTree.mapData(
          typeTree,
          exprTree,
          (_, expr, __) => Literal.getValue(Expr.data(expr)),
        ),
      );
    },
  );

  static final _evalFn = Fn.dart(
    argName: 'constructData',
    argType: type,
    returnType: Any.type,
    body: (ctx, arg) {
      final resultType = Literal.getValue(
        Expr.data(Option.unwrap(eval(ctx, FnApp.mk(_typeFn, Literal.mk(type, arg))))),
      );
      final computedProps = MemberHas.eachEquals(resultType);
      return TypeTree.maybeMapData(
        TypeDef.tree(ctx.getType(Type.id(dataType(arg)))),
        tree(arg),
        (_, dataLeaf, path) =>
            Option.mk(computedProps.containsKey(path) ? null : eval(ctx, dataLeaf)),
      );
    },
  );

  static final exprImplID = ID('ConstructExprImpl');
  static final exprImplDef = Expr.mkImplDef(
    id: exprImplID,
    dataType: type,
    typeCheck: _typeFn,
    reduce: _reduceFn,
    eval: _evalFn,
  );
  static final exprImpl = Expr.mkImpl(
    dataType: type,
    typeCheck: Expr.data(_typeFn),
    reduce: Expr.data(_reduceFn),
    eval: Expr.data(_evalFn),
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
      targetID: TypeTree.mk('target', Literal.mk(Type.type, Expr.type)),
      memberID: TypeTree.mk('accessed', Literal.mk(Type.type, ID.type)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final _typeFn = Fn.dart(
    argName: 'recordAccessData',
    argType: type,
    returnType: Option.type(typeExprType),
    body: (ctx, arg) {
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
                    final bindings = MemberHas.eachEquals(targetType).entries.map(
                          (e) => Binding.mk(
                            id: List.iterate(e.key).last as ID,
                            type: Literal.mk(Type.type, Equals.dataType(e.value)),
                            name: TypeTree.name(
                              TypeTree.treeAt(TypeDef.tree(targetTypeDef), List.iterate(e.key)),
                            ),
                            value: Equals.equalTo(e.value),
                          ),
                        );
                    final evalCtx =
                        bindings.fold<Ctx>(ctx, (ctx, binding) => ctx.withBinding(binding));
                    return Option.cases(
                      typeCheck(evalCtx, leafNode),
                      some: (_) => Option.mk(reduce(evalCtx, leafNode)),
                      none: () => Option.mk(),
                    );
                  },
                );
              },
            );
          } else {
            throw Exception("typechecking recordaccess on non-literal not implemented!");
          }
        },
      );
    },
  );

  static final _reduceFn = Fn.dart(
    argName: 'recordAccessData',
    argType: type,
    returnType: Expr.type,
    body: (ctx, data) {
      final targetExpr = reduce(ctx, target(data));
      if (Expr.dataType(targetExpr) == Literal.type) {
        return (Literal.getValue(Expr.data(targetExpr)) as Dict)[member(data)].unwrap!;
      } else if (Expr.dataType(targetExpr) == Construct.type) {
        return (Construct.tree(Expr.data(targetExpr)) as Dict)[member(data)].unwrap!;
      }
      throw Exception('reduce record access not implemented for record access!');
    },
  );

  static final _evalFn = Fn.dart(
    argName: 'recordAccessData',
    argType: type,
    returnType: Any.type,
    body: (ctx, data) {
      return (eval(ctx, target(data)) as Dict)[member(data)].unwrap!;
    },
  );
  static final exprImplID = ID('exprImpl');
  static final exprImplDef = Expr.mkImplDef(
    id: exprImplID,
    dataType: TypeDef.asType(typeDef),
    typeCheck: _typeFn,
    reduce: _reduceFn,
    eval: _evalFn,
  );
  static final exprImpl = Expr.mkImpl(
    dataType: type,
    typeCheck: Expr.data(_typeFn),
    reduce: _reduceFn,
    eval: Expr.data(_evalFn),
  );

  static Object mk({required Object target, required Object member}) => Expr.mk(
        data: Dict({targetID: target, memberID: member}),
        impl: exprImpl,
      );

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
      typeID: TypeTree.mk('type', Literal.mk(Type.type, Type.type)),
      valueID: TypeTree.mk('value', Var.mk(typeID)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final typeFn = Fn.dart(
    argName: 'literalData',
    argType: type,
    returnType: Option.type(typeExprType),
    body: (ctx, arg) => Option.mk(Literal.mk(Type.type, (arg as Dict)[typeID].unwrap!)),
  );
  static final reduceFn = Fn.dart(
    argName: 'literalData',
    argType: type,
    returnType: Expr.type,
    body: (ctx, arg) => Expr.mk(impl: exprImpl, data: arg),
  );
  static final evalFn = Fn.dart(
    argName: 'literalData',
    argType: type,
    returnType: Any.type,
    body: (ctx, arg) => (arg as Dict)[valueID].unwrap!,
  );
  static final exprImplID = ID('LiteralExprImpl');
  static final exprImplDef = Expr.mkImplDef(
    id: exprImplID,
    dataType: type,
    typeCheck: typeFn,
    reduce: reduceFn,
    eval: evalFn,
  );
  static final Object exprImpl = Expr.mkImpl(
    dataType: type,
    typeCheck: Expr.data(typeFn),
    reduce: Expr.data(reduceFn),
    eval: Expr.data(evalFn),
  );

  static Object mk(Object type, Object value) => Expr.mk(
        impl: exprImpl,
        data: Dict({typeID: type, valueID: value}),
      );

  static Object mkExpr(Object type, Object value) => Expr.mkExpr(
        impl: Literal.mk(Expr.implType, exprImpl),
        data: Construct.mk(Literal.type, Dict({typeID: type, valueID: value})),
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
      IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final _typeFn = Fn.dart(
    argName: 'varData',
    argType: type,
    returnType: Option.type(typeExprType),
    body: (ctx, arg) => Option.cases(
      ctx.getBinding(Var.id(arg)),
      some: (binding) => Option.mk(Binding.valueType(ctx, binding)),
      none: () => Option.mk(),
    ),
  );
  static final _reduceFn = Fn.dart(
    argName: 'varData',
    argType: type,
    returnType: Expr.type,
    body: (ctx, arg) {
      var binding = Option.cases(
        ctx.getBinding(Var.id(arg)),
        some: (binding) => binding,
        none: () => throw Exception(),
      );
      return Option.cases(
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
      );
    },
  );
  static final _evalFn = Fn.dart(
    argName: 'varData',
    argType: type,
    returnType: Any.type,
    body: (ctx, arg) => Option.cases(
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
    ),
  );
  static final exprImplDef = Expr.mkImplDef(
    dataType: type,
    typeCheck: _typeFn,
    reduce: _reduceFn,
    eval: _evalFn,
  );
  static final exprImpl = Expr.mkImpl(
    dataType: type,
    typeCheck: Expr.data(_typeFn),
    reduce: Expr.data(_reduceFn),
    eval: Expr.data(_evalFn),
  );

  static Object mk(ID varID) => Expr.mk(
        data: Dict({IDID: varID}),
        impl: exprImpl,
      );

  static ID id(Object varAccess) => (varAccess as Dict)[IDID].unwrap! as ID;
}

abstract class Placeholder extends Expr {
  static final typeDef = TypeDef.unit('Placeholder');

  static final exprImplDef = Expr.mkImplDef(
    dataType: TypeDef.asType(typeDef),
    typeCheck: Fn.dart(
      argName: '_',
      argType: TypeDef.asType(typeDef),
      returnType: Option.type(typeExprType),
      body: (_, __) => Option.mk(),
    ),
    reduce: Fn.dart(
      argName: '_',
      argType: TypeDef.asType(typeDef),
      returnType: Expr.type,
      body: (_, __) => throw Exception("don't reduce a placeholder u fool!"),
    ),
    eval: Fn.dart(
      argName: '_',
      argType: TypeDef.asType(typeDef),
      returnType: Any.type,
      body: (_, __) => throw Exception("don't evaluate a placeholder u fool!"),
    ),
  );
}

final placeholder = Expr.mk(
  data: const Dict(),
  impl: ImplDef.asImpl(Ctx.empty, Expr.interfaceDef, Placeholder.exprImplDef),
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
    IDID: TypeTree.mk('id', Literal.mk(Type.type, ID.type)),
    valueTypeID: TypeTree.mk('type', Literal.mk(Type.type, typeExprType)),
    nameID: TypeTree.mk('name', Literal.mk(Type.type, text)),
    reducedValueID: TypeTree.mk(
      'reducedValue',
      Fn.typeExpr(
        argType: Literal.mk(Type.type, unit),
        returnType: Option.typeExpr(Expr.type),
      ),
    ),
    valueID: TypeTree.mk(
      'value',
      Fn.typeExpr(
        argType: Literal.mk(Type.type, unit),
        returnType: Option.typeExpr(Var.mk(valueTypeID)),
      ),
    ),
  });
  static final type = TypeDef.asType(def);

  static Object mk({
    required ID id,
    required Object type,
    required String name,
    Object? reducedValue,
    Object? value,
  }) =>
      Dict({
        IDID: id,
        valueTypeID: (Ctx _) => type,
        nameID: name,
        reducedValueID: (Ctx _) => Option.mk(reducedValue),
        valueID: (Ctx _) => Option.mk(value),
      });

  static Object mkLazy({
    required ID id,
    required Object Function(Ctx) type,
    required String name,
    Object? Function(Ctx)? reducedValue,
    Object? Function(Ctx)? value,
  }) =>
      Dict({
        IDID: id,
        valueTypeID: (Ctx ctx) => type(ctx),
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

final coreCtx = Option.unwrap(Module.load(Ctx.empty, coreModule)) as Ctx;

final _substBindingID = ID('subst');
dart.Map<ID, Object> _subst(Ctx ctx) {
  return Option.unwrap(Binding.value(ctx, Option.unwrap(ctx.getBinding(_substBindingID))))
      as dart.Map<ID, Object>;
}

bool assignable(Ctx ctx, Object a, Object b) {
  if (a == b) {
    return true;
  } else if (Expr.dataType(a) == Literal.type) {
    if (Expr.dataType(b) != Literal.type) return false;
    if (Literal.getType(Expr.data(a)) == Type.type) {
      final type1 = Literal.getValue(Expr.data(a));
      final type2 = Literal.getValue(Expr.data(b));
      return typesAssignable(ctx, type1, type2);
    } else {
      return Literal.getValue(Expr.data(a)) == Literal.getValue(Expr.data(b));
    }
  } else if (Expr.dataType(a) == Var.type) {
    final aSubst = _subst(ctx)[Var.id(Expr.data(a))];
    if (aSubst != null) {
      return assignable(ctx, aSubst, b);
    }
    if (Expr.dataType(b) == Var.type) {
      final bSubst = _subst(ctx)[Var.id(Expr.data(b))];
      if (bSubst != null) {
        return assignable(ctx, bSubst, b);
      }
    }
    if (occurs(ctx, Var.id(Expr.data(a)), b)) return false;
    _subst(ctx)[Var.id(Expr.data(a))] = b;
    return true;
  } else if (Expr.dataType(b) == Var.type) {
    return false;
  } else if (Expr.dataType(a) == Construct.type) {
    if (Expr.dataType(b) != Literal.type && Expr.dataType(b) != Construct.type) return false;
    if (Construct.dataType(Expr.data(a)) == Type.type) {
      final type1 = Literal.getValue(Expr.data(a));
      final type2 = Literal.getValue(Expr.data(b));
      return typesAssignable(ctx, type1, type2);
    } else {
      final wrap = Expr.dataType(b) == Literal.type
          ? (Object type, Object value) => Literal.mk(type, value)
          : (Object type, Object value) => value;
      final typeDef = ctx.getType(Type.id(Construct.dataType(Expr.data(a))));
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
            return assignable(ctx, aData, wrap(eval(ctx, leaf), bData));
          },
        );
      }

      return recurse(
        TypeDef.tree(typeDef),
        Construct.tree(Expr.data(a)),
        Construct.tree(Expr.data(b)),
      );
    }
  } else {
    throw Exception(
      'assignable not implemented for exprs (${Expr.dataType(a)}, ${Expr.dataType(b)})',
    );
  }
}

bool occurs(Ctx ctx, ID a, Object b) {
  if (Expr.dataType(b) == Literal.type) return false;
  if (Expr.dataType(b) == Var.type) return Var.id(Expr.data(b)) == a;
  if (Expr.dataType(b) == Construct.type) {
    final typeDef = ctx.getType(Type.id(Construct.dataType(Expr.data(b))));
    bool recurse(Object typeTree, Object bData) {
      return TypeTree.treeCases(
        typeTree,
        record: (record) => record.entries.every(
          (entry) => recurse(entry.value, (bData as Dict)[entry.key].unwrap!),
        ),
        union: (union) => recurse(union[UnionTag.tag(bData)].unwrap!, UnionTag.value(bData)),
        leaf: (leaf) => occurs(ctx, a, bData),
      );
    }

    return recurse(
      TypeDef.tree(typeDef),
      Construct.tree(Expr.data(b)),
    );
  } else {
    throw Exception('occurs not implemented for expr ${Expr.dataType(b)}');
  }
}

bool typesAssignable(Ctx ctx, Object type1, Object type2) {
  if (type1 == Any.type) return true;
  if (Type.id(type1) != Type.id(type2)) return false;
  for (final property1 in List.iterate(Type.properties(type1))) {
    final memberHas1 = TypeProperty.data(property1);
    final path1 = MemberHas.path(memberHas1);
    var found = false;
    for (final property2 in List.iterate(Type.properties(type2))) {
      final memberHas2 = TypeProperty.data(property2);
      if (MemberHas.path(memberHas2) != path1) continue;
      final equals1 = TypeProperty.data(MemberHas.property(memberHas1));
      final equals2 = TypeProperty.data(MemberHas.property(memberHas2));
      if (Equals.dataType(equals1) != Equals.dataType(equals2)) break;
      if (Equals.dataType(equals1) != Type.type) {
        if (Equals.equalTo(equals1) == Equals.equalTo(equals2)) found = true;
      } else {
        if (assignable(
          ctx,
          Literal.mk(Equals.dataType(equals1), Equals.equalTo(equals1)),
          Literal.mk(Equals.dataType(equals2), Equals.equalTo(equals2)),
        )) {
          found = true;
        }
      }
      break;
    }
    if (!found) return false;
  }
  return true;
}

Object dispatch(Ctx ctx, ID interfaceID, Object type) {
  Object? bestImpl;
  Object? bestType;
  for (final binding in ctx.getBindings) {
    if (!interfaceID.isPrefixOf(Binding.id(binding))) continue;
    final bindingType = Binding.valueType(ctx, binding);
    if (!assignable(ctx, bindingType, Literal.mk(Type.type, type))) continue;
    if (bestType != null) {
      if (assignable(ctx, bindingType, bestType)) continue;
      if (!assignable(ctx, bestType, bindingType)) return Option.mk();
    }
    bestType = bindingType;
    bestImpl = Option.unwrap(Binding.value(ctx, binding));
  }
  return Option.mk(bestImpl);
}

Object eval(Ctx ctx, Object expr) {
  final data = Expr.data(expr);
  final dataType = Expr.dataType(expr);
  final evalExprFn = Expr.evalExpr(expr);
  return Fn.bodyCases(
    evalExprFn,
    pal: (bodyExpr) {
      return eval(
        ctx.withBinding(Binding.mk(
          id: Fn.argID(evalExprFn),
          // TODO: this is wronggg
          type: Literal.mk(Type.type, dataType),
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
      type: Literal.mk(Type.type, Any.type),
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

final coreModule = Module.mk(name: 'core', definitions: [
  TypeDef.mkDef(ID.def),
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
  TypeDef.mkDef(MemberHas.typeDef),
  ImplDef.mkDef(MemberHas.propImplDef),
  TypeDef.mkDef(UnionTag.def),
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
  ImplDef.mkDef(Fn.exprImplDef),
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
