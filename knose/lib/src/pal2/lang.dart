// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:core' as dart;
import 'dart:core';
import 'dart:io';
import 'package:ctx/ctx.dart';
import 'package:flutter/foundation.dart';
import 'package:reified_lenses/reified_lenses.dart' as reified;
import 'package:reified_lenses/reified_lenses.dart' show GetCursor, Cursor;
import 'package:uuid/uuid.dart';
// ignore: unused_import
import 'package:knose/src/pal2/print.dart';
import 'package:knose/annotations.dart';

part 'lang.g.dart';

typedef FnMap = dart.Map<ID, Object Function(Ctx, Object)>;
typedef InverseFnMap = dart.Map<Object Function(Ctx, Object), ID>;
typedef Dict = reified.Dict<Object, Object>;
typedef DartList = dart.List<Object>;
typedef Vec = reified.Vec<Object>;
typedef Set = reified.CSet<Object>;

class ID implements Comparable<ID> {
  static const typeDefID =
      ID.constant(id: 'c79400b7-6ea7-44a9-a3af-cecdd5a0c15c', hashCode: 220248298, label: 'ID');
  static final def = TypeDef.unit('ID', id: typeDefID);
  static final type = Type.mk(typeDefID);

  static const _uuid = Uuid();

  final String id;
  final ID? tail;
  final String? label;
  @override
  final int hashCode;

  static ID mk() {
    final id = _uuid.v4();
    return ID.constant(id: id, hashCode: Hash.all(id, null));
  }

  static ID from({
    required String id,
    String? label,
    ID? tail,
  }) =>
      ID.constant(id: id, label: label, tail: tail, hashCode: Hash.all(id, tail));

  const ID.constant({
    required this.id,
    this.label,
    this.tail,
    required this.hashCode,
  });

  ID append(ID other) =>
      ID.from(id: id, label: label, tail: tail == null ? other : tail!.append(other));

  @override
  bool operator ==(Object other) => other is ID && id == other.id && tail == other.tail;

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

  bool isPrefixOf(ID other) {
    if (this.id != other.id) return false;
    if (this.tail == null) return true;
    if (other.tail == null) return false;
    return this.tail!.isPrefixOf(other.tail!);
  }

  bool contains(ID other) {
    if (other.isPrefixOf(this)) return true;
    if (tail == null) return false;
    return tail!.contains(other);
  }

  static final fake = ID.from(id: '00000000-0000-0000-0000-000000000000', label: 'kablooie');
}

abstract class Module {
  static const IDID =
      ID.constant(id: 'cf905c6c-5e71-4cbb-b7ab-4c5e420a74c7', hashCode: 532616109, label: 'ID');
  static const nameID =
      ID.constant(id: 'd9d54c42-e7e6-446d-a85e-78d94682b48b', hashCode: 322951081, label: 'name');
  static const definitionsID = ID.constant(
      id: '73bf53f8-cff1-4c96-98d7-69a722f6b7db', hashCode: 317448442, label: 'definitions');

  static final def = TypeDef.record(
    'Module',
    {
      IDID: TypeTree.mk('id', Type.lit(ID.type)),
      nameID: TypeTree.mk('name', Type.lit(text)),
      definitionsID: TypeTree.mk('definitions', Type.lit(OrderedMap.type(ID.type, ModuleDef.type))),
    },
    id: const ID.constant(id: '5e9ca3d6-0b81-43d2-bf15-981ad734f4ba', hashCode: 7334404),
  );
  static final type = TypeDef.asType(def);

  static Object mk({required ID id, required String name, required DartList definitions}) => Dict({
        IDID: id,
        nameID: name,
        definitionsID: OrderedMap.mk([...definitions.map(ModuleDef.idFor)], definitions)
      });

  static Ctx load(Ctx ctx, DartList modules) =>
      loadReactively(ctx, GetCursor(Vec(modules))).read(Ctx.empty);

  static GetCursor<Ctx> loadReactively(Ctx ctx, GetCursor<Vec> modules) {
    Iterable<Object> expandDef(Ctx ctx, GetCursor<Object> moduleDef) {
      final type = moduleDef[ModuleDef.implID][ModuleDef.dataTypeID].read(ctx);
      final data = moduleDef[ModuleDef.dataID];
      if (type == ValueDef.type) {
        final arg = moduleDef[ModuleDef.dataID];
        final name = arg[ValueDef.nameID];

        GetCursor<Object>? lazyTypeCursor;

        final bindingID = arg[ValueDef.IDID].read(ctx) as ID;
        final expr = arg[ValueDef.valueID];

        computeType(Ctx ctx) {
          lazyTypeCursor ??= GetCursor.compute(
            (ctx) {
              return Result.flatMap(
                typeCheck(updateVisited(ctx, bindingID), expr.read(ctx)),
                (lazyType) {
                  if (Expr.dataType(lazyType) != Literal.type) {
                    return Result.mkErr('binding ${name.read(ctx)} does not have a concrete type');
                  }
                  return Option.cases(
                    arg[ValueDef.expectedTypeID].read(ctx),
                    none: () => Result.mkOk(lazyType),
                    some: (expectedType) => assignableErr(
                      ctx,
                      expectedType,
                      lazyType,
                      'binding ${name.read(ctx)} expression type does not match expected',
                      () => lazyType,
                    ),
                  );
                },
                'type checking binding ${name.read(ctx)} failed',
              );
            },
            ctx: ctx,
          );
          return lazyTypeCursor!.read(ctx);
        }

        GetCursor<Object>? lazyValueCursor;
        computeValue(Ctx ctx) {
          lazyValueCursor ??= GetCursor.compute((ctx) {
            computeType(ctx);
            return eval(updateVisited(ctx, bindingID), expr.read(ctx));
          }, ctx: ctx);
          return lazyValueCursor!.read(ctx);
        }

        GetCursor<String>? lazyNameCursor;
        computeName(Ctx ctx) {
          lazyNameCursor ??= GetCursor.compute((ctx) {
            computeType(ctx);
            return eval(
              ctx,
              FnApp.mk(
                Literal.mk(
                  Fn.type(argID: ValueDef.nameArgID, argType: unit, returnType: Type.lit(text)),
                  name.read(ctx),
                ),
                unitExpr,
              ),
            ) as String;
          }, ctx: ctx);
          return lazyNameCursor!.read(ctx);
        }

        return [
          Binding.mkLazy(
            id: bindingID,
            name: computeName,
            type: computeType,
            value: computeValue,
          ),
        ];
      } else if (type == InterfaceDef.type) {
        return [
          ValueDef.mkCursor(
            id: data[InterfaceDef.IDID],
            name: data[InterfaceDef.treeID][TypeTree.nameID],
            value: Literal.mkCursor(GetCursor(InterfaceDef.type), data),
          ),
          TypeDef.mkCursorDef(
            tree: data[InterfaceDef.treeID],
            id: GetCursor.computeMT(
              (ctx) => InterfaceDef.innerTypeDefID(data[InterfaceDef.IDID].read(ctx) as ID),
            ),
          ),
          ValueDef.mkCursor(
            id: GetCursor.computeMT(
                (ctx) => InterfaceDef.dispatchCacheID(data[InterfaceDef.IDID].read(ctx) as ID)),
            name: GetCursor.computeMT(
                (ctx) => '${data[InterfaceDef.treeID][TypeTree.nameID].read(ctx)} dispatch cache'),
            value: Literal.mkCursor(
              GetCursor.computeMT(
                (ctx) => Map.type(
                  Type.type,
                  InterfaceDef.implTypeByID(data[InterfaceDef.IDID].read(ctx) as ID),
                ),
              ),
              // ignore: prefer_const_constructors
              GetCursor(<Object, Object>{}),
            ),
          ),
        ].expand((element) => expandDef(ctx, element));
      } else if (type == TypeDef.type) {
        final comptime =
            (data[TypeDef.comptimeID][List.itemsID].read(ctx) as Iterable<Object>).cast<ID>();
        final typeTree = data[TypeDef.treeID];
        final typeName = typeTree[TypeTree.nameID];

        return [
          ValueDef.mkCursor(
            id: data[TypeDef.IDID],
            name: typeName,
            value: Literal.mkCursor(GetCursor(TypeDef.type), data),
          ),
          // TODO: make reactive?
          if (comptime.isNotEmpty)
            TypeDef.mkCursorRecordDef(
              name: GetCursor.computeMT((ctx) => '${typeName.read(ctx)}TypeArgs'),
              members: {for (final id in comptime) id: TypeTree.findReactive(ctx, typeTree, id)!},
              id: GetCursor.computeMT(
                  (ctx) => TypeDef.typeArgsIDFor(data[TypeDef.IDID].read(ctx) as ID)),
            ),
          ValueDef.mkCursor(
            id: GetCursor.computeMT(
              (ctx) => TypeDef.typeConstructorIDFor(data[TypeDef.IDID].read(ctx) as ID),
            ),
            name: typeTree[TypeTree.nameID],
            value: comptime.isEmpty
                ? GetCursor.computeMT(
                    (ctx) => Type.lit(Type.mk(data[TypeDef.IDID].read(ctx) as ID)))
                : FnExpr.mkFromCursor(
                    argID: const GetCursor(TypeDef.typeConstructorArgID),
                    argName: const GetCursor('typeArgs'),
                    argType: Var.mkCursor(
                      GetCursor.computeMT(
                        (ctx) => TypeDef.typeConstructorIDFor(
                            TypeDef.typeArgsIDFor(data[TypeDef.IDID].read(ctx) as ID)),
                      ),
                    ),
                    returnType: (_) => GetCursor(Type.lit(Type.type)),
                    // TODO: mkexprcursor??? bleh
                    body: (arg) => GetCursor.computeMT(
                      (ctx) {
                        return Type.mkExpr(data[TypeDef.IDID].read(ctx) as ID, properties: [
                          for (final id in comptime)
                            MemberHas.mkEqualsExpr(
                              [id],
                              TypeTree.findReactive(ctx, typeTree, id)![TypeTree.treeID]
                                      [UnionTag.valueID]
                                  .read(ctx),
                              RecordAccess.mk(arg.read(ctx), id),
                            ),
                        ]);
                      },
                    ),
                  ),
          ),
          for (final entry in TypeTree.allTrees(ctx, typeTree).entries)
            ValueDef.mkCursor(
              id: GetCursor(entry.key),
              name: GetCursor.computeMT(
                (ctx) => '${typeName.read(ctx)}.${entry.value[TypeTree.nameID].read(ctx)}',
              ),
              value: GetCursor(Literal.mk(ID.type, entry.key)),
            )
        ].expand((element) => expandDef(ctx, element));
      } else if (type == ImplDef.type) {
        return expandDef(
          ctx,
          ValueDef.mkCursorWithNameFn(
            id: GetCursor.computeMT(
              (ctx) => ImplDef.bindingIDForIDs(
                implID: data[ImplDef.IDID].read(ctx) as ID,
                interfaceID: data[ImplDef.implementedID].read(ctx) as ID,
              ),
            ),
            name: GetCursor.computeMT(
              (ctx) => FnApp.mk(
                textAppendFnExpr,
                List.mkExpr(text, [
                  RecordAccess.chain(
                    Var.mk(data[ImplDef.implementedID].read(ctx) as ID),
                    [InterfaceDef.treeID, TypeTree.nameID],
                  ),
                  Literal.mk(text, '.${data[ImplDef.nameID].read(ctx)}')
                ]),
              ),
            ),
            value: data[ImplDef.definitionID],
          ),
        );
      } else {
        throw UnimplementedError();
      }
    }

    return GetCursor.compute(
      (ctx) => modules
          .values(ctx)
          .expand(
            (module) => module[Module.definitionsID][OrderedMap.keyOrderID][List.itemsID]
                .cast<Vec>()
                .read(ctx)
                .expand(
                  (defID) => expandDef(
                    ctx,
                    module[Module.definitionsID][OrderedMap.valueMapID][Map.entriesID]
                        .cast<Dict>()[defID]
                        .whenPresent,
                  ),
                ),
          )
          .fold(ctx, (ctx, binding) => ctx.withBinding(binding)),
      ctx: ctx,
    );
  }

  static Future<Object> loadFromFile(String name) =>
      File('pal/$name.pal').readAsString().then((str) => deserialize(str) as Object);

  static final bindingOrType = Union.type([ModuleDef.type, Binding.type]);

  static String name(Object module) => (module as Dict)[Module.nameID].unwrap! as String;
}

abstract class ModuleDef extends InterfaceDef {
  static const dataTypeID = ID.constant(
      id: 'ca0051e6-45c7-44d8-9da0-79f16e17ad0f', hashCode: 415278287, label: 'dataType');

  static const bindingsID = ID.constant(
      id: 'ef45d862-6c1c-4dda-aadf-a8e611ff3fe4', hashCode: 268996972, label: 'bindings');

  static const bindingsArgID = ID.constant(
      id: '649453ed-3f2e-41df-85da-2cbd314f71df', hashCode: 524918232, label: 'bindingsArg');

  static final interfaceDef = InterfaceDef.record(
    'ModuleDef',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      bindingsID: TypeTree.mk(
        'bindings',
        Fn.typeExpr(
          argID: bindingsArgID,
          argType: Var.mk(dataTypeID),
          returnType: Type.lit(List.type(Module.bindingOrType)),
        ),
      ),
    },
    id: const ID.constant(id: 'df55c7f5-cef0-48c5-9315-85576d4a8f77', hashCode: 536841652),
  );

  static Object mkImpl({
    required Object dataType,
    required Object bindings,
    required ID id,
    required String name,
  }) =>
      ImplDef.mk(
        id: id,
        name: name,
        implemented: InterfaceDef.id(interfaceDef),
        definition: Dict({
          dataTypeID: Type.lit(dataType),
          bindingsID: bindings,
        }),
      );

  static const implID =
      ID.constant(id: 'b4919631-a2e0-497b-8309-80b8c18f97b5', hashCode: 351840823, label: 'impl');

  static const dataID =
      ID.constant(id: '661c5818-62cb-4122-b262-6ba7b3205e2d', hashCode: 160646736, label: 'data');

  static const typeDefID = ID.constant(
      id: '8564c2e2-5ceb-4398-9c20-2afcdd845968', hashCode: 438744664, label: 'ModuleDef');

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

  static Object mk({required Object impl, required Object data}) =>
      Dict({implID: impl, dataID: data});
  static GetCursor<Object> mkCursor({required Object impl, required GetCursor<Object> data}) =>
      Dict.cursor({dataID: data, implID: GetCursor(impl)});

  static Object impl(Object moduleDef) => (moduleDef as Dict)[implID].unwrap!;
  static Object dataType(Object moduleDef) => (impl(moduleDef) as Dict)[dataTypeID].unwrap!;
  static Object data(Object moduleDef) => (moduleDef as Dict)[dataID].unwrap!;

  static ID idFor(Object moduleDef) {
    final type = ModuleDef.dataType(moduleDef);
    if (type == TypeDef.type) {
      return TypeDef.id(ModuleDef.data(moduleDef));
    } else if (type == InterfaceDef.type) {
      return InterfaceDef.id(ModuleDef.data(moduleDef));
    } else if (type == ImplDef.type) {
      return ImplDef.id(ModuleDef.data(moduleDef));
    } else if (type == ValueDef.type) {
      return ValueDef.id(ModuleDef.data(moduleDef));
    } else {
      throw UnimplementedError('unknown moduleDef type $type');
    }
  }
}

abstract class ValueDef {
  static const IDID =
      ID.constant(id: 'c441c1b1-cb2f-4f62-b794-985b6bea8f36', hashCode: 326891059, label: 'ID');
  static const nameID =
      ID.constant(id: 'c1e49d93-30b4-4588-8877-98c43d5f8606', hashCode: 435572148, label: 'name');
  static const nameArgID =
      ID.constant(id: 'c1e49d93-30b4-4588-8877-98c43d5f8606', hashCode: 435572148, label: 'name');
  static const expectedTypeID = ID.constant(
      id: '750bfe41-a85d-4895-874b-38f17c2067f6', hashCode: 329201515, label: 'expectedType');
  static const valueID =
      ID.constant(id: 'd842696a-2c8b-42ec-a155-9d6215b25413', hashCode: 329211109, label: 'value');

  static final typeDef = TypeDef.record(
    'ValueDef',
    {
      IDID: TypeTree.mk('id', Type.lit(ID.type)),
      nameID: TypeTree.mk(
        'name',
        Type.lit(Fn.type(argID: nameArgID, argType: unit, returnType: Type.lit(text))),
      ),
      expectedTypeID: TypeTree.mk('expectedType', Type.lit(Option.type(Type.type))),
      valueID: TypeTree.mk('value', Type.lit(Expr.type)),
    },
    id: const ID.constant(id: '3f61635c-a401-4bd4-a2d8-8a35251469a5', hashCode: 202619742),
  );
  static final type = TypeDef.asType(typeDef);

  static Object mk({
    required ID id,
    required String name,
    Object? expectedType,
    required Object value,
  }) =>
      ModuleDef.mk(
        impl: moduleDefImpl,
        data: Dict({
          IDID: id,
          nameID: Fn.mk(argID: nameArgID, argName: '_', body: Fn.mkPalBody(Literal.mk(text, name))),
          expectedTypeID: Option.mk(expectedType),
          valueID: value,
        }),
      );

  static GetCursor<Object> mkCursor({
    required GetCursor<Object> id,
    required GetCursor<Object> name,
    GetCursor<Object>? expectedType,
    required GetCursor<Object> value,
  }) =>
      ModuleDef.mkCursor(
        impl: moduleDefImpl,
        data: Dict.cursor({
          IDID: id,
          nameID: Fn.mkCursor(
            argID: const GetCursor(nameArgID),
            argName: const GetCursor('_'),
            body: Fn.mkPalBodyCursor(Literal.mkCursor(GetCursor(text), name)),
          ),
          expectedTypeID: Option.mkCursor(expectedType),
          valueID: value,
        }),
      );

  static GetCursor<Object> mkCursorWithNameFn({
    required GetCursor<Object> id,
    required GetCursor<Object> name,
    GetCursor<Object>? expectedType,
    required GetCursor<Object> value,
  }) =>
      ModuleDef.mkCursor(
        impl: moduleDefImpl,
        data: Dict.cursor({
          IDID: id,
          nameID: Fn.mkCursor(
            argID: const GetCursor(nameArgID),
            argName: const GetCursor('_'),
            body: Fn.mkPalBodyCursor(name),
          ),
          expectedTypeID: Option.mkCursor(expectedType),
          valueID: value,
        }),
      );

  static final moduleDefImplDef = ModuleDef.mkImpl(
    name: 'ValueDef',
    dataType: type,
    bindings: FnExpr.dart(
      argID: ModuleDef.bindingsArgID,
      argName: 'valueDef',
      argType: Type.lit(type),
      returnType: Type.lit(List.type(Module.bindingOrType)),
      body: ID.fake,
    ),
    id: const ID.constant(
        id: '52b13cdf-4771-42e8-bdbb-93d4ccc2db37', hashCode: 443583250, label: 'ValueDefImpl'),
  );
  static final moduleDefImpl =
      ImplDef.asImpl(Ctx.empty.withFnMap(langFnMap), ModuleDef.interfaceDef, moduleDefImplDef);

  static ID id(Object valueDef) => (valueDef as Dict)[IDID].unwrap! as ID;
}

abstract class TypeDef {
  static const IDID =
      ID.constant(id: '9234172f-4ecc-454e-8837-60f08c7d1f58', hashCode: 102864945, label: 'ID');

  static const comptimeID = ID.constant(
      id: '68d2b51f-1018-4ec2-a785-b47143ddbb58', hashCode: 492289506, label: 'comptime');

  static const treeID =
      ID.constant(id: '889690b1-bc8d-4bab-a3ec-93bced68b943', hashCode: 197296904, label: 'tree');

  static Object record(
    String name,
    dart.Map<ID, Object> members, {
    required ID id,
    DartList comptime = const [],
  }) =>
      mk(TypeTree.record(name, members), id: id, comptime: comptime);
  static Object union(
    String name,
    dart.Map<ID, Dict> cases, {
    required ID id,
    DartList comptime = const [],
  }) =>
      mk(TypeTree.union(name, cases), id: id, comptime: comptime);
  static Object unit(String name, {required ID id}) => mk(TypeTree.unit(name), id: id);

  static Object mk(Object tree, {required ID id, DartList comptime = const []}) =>
      Dict({IDID: id, comptimeID: List.mk(comptime), treeID: tree});
  static GetCursor<Object> mkCursorDef({
    required GetCursor<Object> tree,
    required GetCursor<Object> id,
    GetCursor<Vec> comptime = const GetCursor(Vec()),
  }) =>
      ModuleDef.mkCursor(
        impl: moduleDefImpl,
        data: Dict.cursor({IDID: id, treeID: tree, comptimeID: List.mkCursor(comptime)}),
      );

  static GetCursor<Object> mkCursorRecordDef({
    required GetCursor<Object> name,
    required dart.Map<ID, GetCursor<Object>> members,
    required GetCursor<Object> id,
  }) =>
      mkCursorDef(id: id, tree: TypeTree.mkRecordCursor(name, members));

  static Object asType(Object typeDef, {DartList properties = const []}) => Type.mk(
        (typeDef as Dict)[IDID].unwrap! as ID,
        properties: properties,
      );

  static ID id(Object typeDef) => (typeDef as Dict)[IDID].unwrap! as ID;
  static Iterable<ID> comptime(Object typeDef) =>
      List.iterate((typeDef as Dict)[comptimeID].unwrap!).cast<ID>();
  static Object tree(Object typeDef) => (typeDef as Dict)[treeID].unwrap!;

  static final def = TypeDef.record(
    'TypeDef',
    {
      IDID: TypeTree.mk('id', Type.lit(ID.type)),
      comptimeID: TypeTree.mk('comptime', Type.lit(List.type(ID.type))),
      treeID: TypeTree.mk('tree', Type.lit(TypeTree.type)),
    },
    id: const ID.constant(id: 'efb5d9f0-79ef-4d03-8fb4-08597aa8d531', hashCode: 160382566),
  );
  static final type = asType(def);

  static final moduleDefImplDef = ModuleDef.mkImpl(
    name: 'TypeDef',
    dataType: type,
    bindings: FnExpr.dart(
      argID: ModuleDef.bindingsArgID,
      argName: 'typeDef',
      argType: Type.lit(type),
      returnType: Type.lit(List.type(Module.bindingOrType)),
      body: ID.fake,
    ),
    id: const ID.constant(
        id: '9236177b-15c5-4124-ad20-4bfc443a2af5', hashCode: 402914795, label: 'TypeDefImpl'),
  );
  static final moduleDefImpl =
      ImplDef.asImpl(Ctx.empty.withFnMap(langFnMap), ModuleDef.interfaceDef, moduleDefImplDef);

  static Object mkDef(Object def) => ModuleDef.mk(impl: moduleDefImpl, data: def);

  static ID typeConstructorIDFor(ID id) => id.append(_typeConstructorID);
  static const _typeConstructorID = ID.constant(
      id: 'c60a9c79-2254-4ed4-a7a1-4b6c19a90346', hashCode: 362484140, label: 'TypeConstructor');
  static const typeConstructorArgID =
      ID.constant(id: '2f034e10-516f-4a90-b252-757e863a394c', hashCode: 141926094);

  static ID typeArgsIDFor(ID id) => id.append(typeArgsID);
  static const typeArgsID = ID.constant(
      id: '04443546-52ad-4236-832f-c68b178b3856', hashCode: 207883027, label: 'TypeArgs');

  static bool isTypeConstructorID(ID id) => id.contains(_typeConstructorID);
}

abstract class Type {
  static const IDID =
      ID.constant(id: 'a28a156a-bcea-4606-9830-dcd34b414044', hashCode: 303242969, label: 'ID');

  static const pathID =
      ID.constant(id: 'ac4de6ad-864d-4c8e-89a7-57f7af493003', hashCode: 198777100, label: 'path');

  static const propertiesID = ID.constant(
      id: 'b32d8c5a-6513-4cf0-867d-3dba59656e6e', hashCode: 169791881, label: 'properties');

  static const _typeID =
      ID.constant(id: '6c1d5fb9-b1e7-4ff5-a8ad-a8f25f270156', hashCode: 178744587, label: 'Type');

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
          propertiesID: List.mkExpr(Type.lit(TypeProperty.type), properties),
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
  static const dataTypeID = ID.constant(
      id: '75d2b8ec-ff22-4c68-8423-72f210092aa1', hashCode: 494493746, label: 'dataType');

  static const interfaceID = ID.constant(
      id: 'a4dbc0f9-adfe-45b6-b65d-56c471b897a2', hashCode: 341377764, label: 'TypeProperty');

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
    required String name,
  }) =>
      ImplDef.mk(
        name: name,
        id: id,
        implemented: interfaceID,
        definition: Dict({dataTypeID: Type.lit(dataType)}),
      );

  static const implID =
      ID.constant(id: 'c63d7901-2b2e-49c4-b619-e885bb319ae8', hashCode: 21829240, label: 'impl');

  static const dataID =
      ID.constant(id: '329b1a1d-fdad-4bc8-b46a-844126b8b8fd', hashCode: 459810058, label: 'data');

  static final typeDef = TypeDef.record(
    'TypeProperty',
    {
      implID: TypeTree.mk('impl', Type.lit(implType)),
      dataID: TypeTree.mk(
        'data',
        RecordAccess.mk(Var.mk(implID), dataTypeID),
      ),
    },
    id: const ID.constant(id: '5b98db2b-8fac-467a-b583-6796f920a144', hashCode: 111057732),
  );
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
  static const dataTypeID = ID.constant(
      id: '0b574b87-30b8-4727-a0c1-4cc306503bb5', hashCode: 338351793, label: 'dataType');

  static const equalToID = ID.constant(
      id: '490a3580-6f73-4e38-8e57-ca99c3c84cb1', hashCode: 445973261, label: 'equalTo');

  static const typeDefID =
      ID.constant(id: 'a41bed42-1341-414a-83c6-f94e5baf473a', hashCode: 480239291, label: 'Equals');

  static final typeDef = TypeDef.record(
    'Equals',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      equalToID: TypeTree.mk('equalTo', Var.mk(dataTypeID)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final propImplDef = TypeProperty.mkImpl(
    id: const ID.constant(
        id: 'e754cfb6-d4fa-4884-ac4c-40cecfa1d851', hashCode: 335104296, label: 'EqualsImpl'),
    name: 'Equals',
    dataType: type,
  );
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
  static const pathID =
      ID.constant(id: '29332a1f-c57e-4a2c-a89d-15fde53d0575', hashCode: 57823015, label: 'path');

  static const propertyID = ID.constant(
      id: '5851a4f1-4b4f-4271-b35c-d7d1bc6317e3', hashCode: 63111110, label: 'property');

  static const typeDefID = ID.constant(
      id: 'e70d358a-4911-4a86-8661-fd9263dd74f6', hashCode: 217541326, label: 'MemberHas');

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
    name: 'MemberHas',
    id: const ID.constant(
        id: 'b876dad4-949d-4b3c-bcb6-257166644158', hashCode: 470405332, label: 'MemberHasImpl'),
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

class UnionTag extends Dict {
  static const tagID =
      ID.constant(id: 'ebc689d7-167b-49c9-9d96-c06228da1bab', hashCode: 508643769, label: 'tag');

  static const valueID =
      ID.constant(id: 'cb1254dd-1f07-4c45-bf5c-517fe7bf9937', hashCode: 490888290, label: 'value');

  static final def = TypeDef.record(
    'UnionTag',
    {
      tagID: TypeTree.mk('tag', Type.lit(ID.type)),
      valueID: TypeTree.mk('value', Type.lit(Any.type)),
    },
    id: const ID.constant(id: '5fb4d4b1-8743-4e31-9878-eab42ec483b6', hashCode: 482709390),
  );

  static final type = TypeDef.asType(def);

  static Dict mk(ID tag, Object value) => Dict({tagID: tag, valueID: value});
  static GetCursor<Object> mkCursor(ID tag, GetCursor<Object> value) =>
      Dict.cursor({valueID: value, tagID: GetCursor(tag)});

  static ID tag(Object unionTag) => (unionTag as Dict)[tagID].unwrap! as ID;
  static Object value(Object unionTag) => (unionTag as Dict)[valueID].unwrap!;
}

abstract class TypeTree {
  static const nameID =
      ID.constant(id: '6c2239f9-fce8-4ddb-b2f0-7acfc5a109c6', hashCode: 204989073, label: 'name');

  static const treeID =
      ID.constant(id: 'fb489a21-eb81-45c1-a752-47431bc67501', hashCode: 50170016, label: 'tree');

  static const recordID =
      ID.constant(id: 'fc0efb56-e6dd-4d6d-8f3c-c2440124f251', hashCode: 394119794, label: 'record');

  static const unionID =
      ID.constant(id: '0277e3b5-0802-4120-b2c2-9915bc1d9a38', hashCode: 157424920, label: 'union');

  static const leafID =
      ID.constant(id: '100090cc-5382-4603-b4ff-f1f0995c021d', hashCode: 138565156, label: 'leaf');

  static const id = ID.constant(
      id: '0e6ae671-776d-488e-a779-3dbc0609615c', hashCode: 34273951, label: 'TypeTree');
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

  static GetCursor<Object> mkRecordCursor(
          GetCursor<Object> name, dart.Map<ID, GetCursor<Object>> members) =>
      Dict.cursor({nameID: name, treeID: UnionTag.mkCursor(recordID, Map.mkCursor(members))});

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

  static Ctx typeBindings(Ctx ctx, Object typeTree, [ID? id]) {
    return treeCases(
      typeTree,
      record: (record) =>
          record.entries.fold(ctx, (ctx, e) => typeBindings(ctx, e.value, e.key as ID)),
      union: (union) => ctx,
      leaf: (leaf) {
        if (id == null) return ctx;
        return ctx.withBinding(Binding.mkLazy(
          id: id,
          name: (_) => TypeTree.name(typeTree),
          type: (ctx) => Result.mkOk(reduce(ctx, leaf)),
        ));
      },
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
          name: (_) => (path.last as ID).label ?? '${path.last}',
          type: (ctx) => Result.mkOk(reduce(ctx, typeLeaf)),
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

  static dart.Map<ID, GetCursor<Object>> allTrees(Ctx ctx, GetCursor<Object> typeTree) {
    final treeCase = typeTree[treeID][UnionTag.tagID].read(ctx);
    var dict = const GetCursor(Dict());
    if (treeCase == recordID || treeCase == unionID) {
      dict = typeTree[treeID][UnionTag.valueID][Map.entriesID].cast<Dict>();
    }
    final keys = dict.keys.read(ctx).cast<ID>();
    return {
      for (final key in keys) ...{
        key: dict[key].whenPresent,
        ...allTrees(ctx, dict[key].whenPresent)
      },
    };
  }

  static Object? find(Object typeTree, ID id) {
    final dict = treeCases(
      typeTree,
      record: (record) => record,
      union: (union) => union,
      leaf: (_) => const Dict(),
    );
    for (final entry in dict.entries) {
      if (id == entry.key) {
        return entry.value;
      }
      final subFind = find(entry.value, id);
      if (subFind != null) {
        return subFind;
      }
    }
    return null;
  }

  static GetCursor<Object>? findReactive(Ctx ctx, GetCursor<Object> typeTree, ID id) {
    final treeCase = typeTree[treeID][UnionTag.tagID].read(ctx);
    var dict = const GetCursor(Dict());
    if (treeCase == recordID || treeCase == unionID) {
      dict = typeTree[treeID][UnionTag.valueID][Map.entriesID].cast<Dict>();
    }
    for (final key in dict.keys.read(ctx)) {
      if (id == key) {
        return dict[key].whenPresent;
      }
      final subFind = findReactive(ctx, dict[key].whenPresent, id);
      if (subFind != null) {
        return subFind;
      }
    }
    return null;
  }
}

abstract class InterfaceDef {
  static const IDID =
      ID.constant(id: 'ef1a8c93-483f-4335-88ae-4b5bbe2f3146', hashCode: 356292979, label: 'ID');

  static const treeID =
      ID.constant(id: '36e28e87-1563-4ff7-9100-033146102507', hashCode: 296821927, label: 'tree');

  static final def = TypeDef.record(
    'InterfaceDef',
    {
      IDID: TypeTree.mk('id', Type.lit(ID.type)),
      treeID: TypeTree.mk('tree', Type.lit(TypeTree.type)),
    },
    id: const ID.constant(id: '735883c8-1b4a-4949-9cb0-1b1e7391be08', hashCode: 508445355),
  );
  static final type = TypeDef.asType(def);

  static Dict mk(Dict tree, {required ID id}) => Dict({IDID: id, treeID: tree});
  static Object record(String name, dart.Map<ID, Dict> members, {required ID id}) =>
      InterfaceDef.mk(TypeTree.record(name, members), id: id);
  static Dict union(String name, dart.Map<ID, Dict> cases, {required ID id}) =>
      InterfaceDef.mk(TypeTree.union(name, cases), id: id);

  static ID id(Object ifaceDef) => (ifaceDef as Dict)[IDID].unwrap! as ID;
  static Object tree(Object ifaceDef) => (ifaceDef as Dict)[treeID].unwrap!;

  static const _innerTypeDefID = ID.constant(
      id: '7412698d-6c16-4627-88db-c4d512c37216', hashCode: 366469750, label: 'typeDef');

  static const _dispatchCacheID = ID.constant(
      id: '432d66c8-63e3-4cf5-b05d-f4ea61a98be6', hashCode: 146540200, label: 'dispatchCache');

  static ID innerTypeDefID(ID id) => id.append(_innerTypeDefID);
  static ID dispatchCacheID(ID id) => id.append(_dispatchCacheID);
  static final moduleDefImplDef = ModuleDef.mkImpl(
    name: 'InterfaceDef',
    dataType: type,
    bindings: FnExpr.dart(
      argID: ModuleDef.bindingsArgID,
      argName: 'interfaceDef',
      argType: Type.lit(type),
      returnType: Type.lit(List.type(Module.bindingOrType)),
      body: ID.fake,
    ),
    id: const ID.constant(
        id: '970807fb-7618-49c3-b657-c136ed4ba1e0', hashCode: 240586499, label: 'InterfaceDefImpl'),
  );

  static final moduleDefImpl =
      ImplDef.asImpl(Ctx.empty.withFnMap(langFnMap), ModuleDef.interfaceDef, moduleDefImplDef);

  static Object mkDef(Object def) => ModuleDef.mk(impl: moduleDefImpl, data: def);
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
  static const IDID =
      ID.constant(id: '672645db-27d7-475e-b318-64f5d3f2d82d', hashCode: 528256935, label: 'ID');

  static const nameID =
      ID.constant(id: '551230e0-16fb-49c1-b273-0c4fa7c599a2', hashCode: 160150517, label: 'name');

  static const implementedID = ID.constant(
      id: '551230e0-66fb-49c1-b273-0c4fa7c599a2', hashCode: 295780074, label: 'implemented');

  static const definitionID = ID.constant(
      id: '9cc447df-ae3e-4566-84a7-2bd908cb28c0', hashCode: 515187887, label: 'definition');

  static const definitionArgID = ID.constant(
      id: '140bdf0f-eb94-4942-927d-70a27eff547a', hashCode: 483485653, label: 'definitionArg');

  static final def = TypeDef.record(
    'ImplDef',
    {
      IDID: TypeTree.mk('id', Type.lit(ID.type)),
      nameID: TypeTree.mk('name', Type.lit(text)),
      implementedID: TypeTree.mk('implemented', Type.lit(ID.type)),
      definitionID: TypeTree.mk('definition', Type.lit(Expr.type)),
    },
    id: const ID.constant(id: '431de7b8-4662-441d-85f1-b84b37623232', hashCode: 30812446),
  );
  static final type = TypeDef.asType(def);

  static Object mk({
    required ID id,
    required String name,
    required ID implemented,
    required Object definition,
  }) =>
      mkParameterized(
        id: id,
        name: name,
        implemented: implemented,
        argType: unit,
        definition: (_) => definition,
      );

  static Dict mkParameterized({
    required ID id,
    required String name,
    required ID implemented,
    required Object argType,
    required Object Function(Object) definition,
  }) =>
      Dict({
        IDID: id,
        nameID: name,
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

  static const _bindingIDPrefixID = ID.constant(
      id: '3dc81333-74ed-48bb-a3a6-7d1cf97319c8', hashCode: 362710046, label: 'BindingIDPrefix');

  static ID bindingIDPrefixForID(ID interfaceID) => _bindingIDPrefixID.append(interfaceID);
  static ID bindingID(Object implDef) =>
      bindingIDForIDs(interfaceID: ImplDef.implemented(implDef), implID: ImplDef.id(implDef));
  static ID bindingIDForIDs({required ID implID, required ID interfaceID}) =>
      bindingIDPrefixForID(interfaceID).append(implID);
  static final moduleDefImplDef = ModuleDef.mkImpl(
    name: 'ImplDef',
    dataType: type,
    bindings: FnExpr.dart(
      argID: ModuleDef.bindingsArgID,
      argName: 'implDef',
      argType: Type.lit(type),
      returnType: Type.lit(List.type(Module.bindingOrType)),
      body: ID.fake,
    ),
    id: const ID.constant(
        id: 'd3a12fbe-f4b6-4129-8183-cce33ce42b05', hashCode: 3876398, label: 'ImplDefImpl'),
  );
  static final moduleDefImpl =
      ImplDef.asImpl(Ctx.empty.withFnMap(langFnMap), ModuleDef.interfaceDef, moduleDefImplDef);

  static Object mkDef(Object def) => ModuleDef.mk(impl: moduleDefImpl, data: def);

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
  static const possibleTypesID = ID.constant(
      id: 'de2fd937-c8c1-4f43-87cc-39cd9f974d93', hashCode: 385961892, label: 'dataType');

  static const thisTypeID = ID.constant(
      id: 'c9e4a051-aaea-4dc8-9622-ac69a5f948a3', hashCode: 448638895, label: 'thisType');

  static const valueID =
      ID.constant(id: 'b25981ca-3378-4d2f-a79a-0ca68a5425cb', hashCode: 360204934, label: 'value');

  static final def = TypeDef.record(
    'Union',
    {
      possibleTypesID: TypeTree.mk('possibleTypes', Type.lit(List.type(Type.type))),
      thisTypeID: TypeTree.mk('thisType', Type.lit(Type.type)),
      valueID: TypeTree.mk('value', Var.mk(thisTypeID)),
    },
    id: const ID.constant(id: 'd441a18a-8320-49c2-8669-8bfe27b08f59', hashCode: 10276879),
  );

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
  static const firstTypeID =
      ID.constant(id: '39012ab4-aec5-4707-b004-85f9e31f4c79', hashCode: 73773440, label: 'First');

  static const secondTypeID =
      ID.constant(id: 'f2b678ab-1b34-4613-b6f7-88907990d084', hashCode: 437302955, label: 'Second');

  static const firstID =
      ID.constant(id: '48e0b3c5-3f3c-4273-b952-3c82b258356f', hashCode: 57881127, label: 'first');

  static const secondID =
      ID.constant(id: '18e565b5-ee20-4c41-a175-5d73197bb064', hashCode: 300200603, label: 'second');

  static final def = TypeDef.record(
    'Pair',
    {
      firstTypeID: TypeTree.mk('First', Type.lit(Type.type)),
      secondTypeID: TypeTree.mk('Second', Type.lit(Type.type)),
      firstID: TypeTree.mk('first', Var.mk(firstTypeID)),
      secondID: TypeTree.mk('second', Var.mk(secondTypeID)),
    },
    comptime: [firstTypeID, secondTypeID],
    id: const ID.constant(id: '25ccfe71-9c35-4ac8-9d4f-d169f6cef165', hashCode: 59087433),
  );

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
  static const dataTypeID = ID.constant(
      id: '65d1ec90-6ae3-4656-ae97-e841204ff433', hashCode: 341412707, label: 'dataType');

  static const valueID =
      ID.constant(id: '0637ed04-4480-4ba5-9e34-66373ec0f16e', hashCode: 160567884, label: 'value');

  static const someID =
      ID.constant(id: '54b54373-ceb0-435a-b12c-051e06075473', hashCode: 405428472, label: 'some');

  static const noneID =
      ID.constant(id: '066cffa7-bb7a-4e24-95e2-cd16bcf72a50', hashCode: 338797295, label: 'none');

  static const typeDefID =
      ID.constant(id: 'dba2b8d2-11ec-4c56-91e8-fd9af7d9851f', hashCode: 227142816, label: 'Option');

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
      cases(option, some: (val) => Option.mk(f(val)), none: () => Option.mk());

  static Object unwrap(Object option, {Object Function()? orElse}) => Option.cases(
        option,
        some: (v) => v,
        none: () => orElse != null ? orElse() : throw Exception(),
      );

  static bool isPresent(Object option) =>
      Option.cases(option, some: (_) => true, none: () => false);

  static final _noneValue = Dict({valueID: UnionTag.mk(noneID, const Dict())});
  static Object mk([Object? value]) => value == null
      ? _noneValue
      : Dict({
          valueID: UnionTag.mk(someID, value),
        });

  static GetCursor<Object> mkCursor([GetCursor<Object>? value]) => value == null
      ? GetCursor(_noneValue)
      : Dict.cursor({valueID: UnionTag.mkCursor(someID, value)});

  static Object someExpr(Object dataType, Object value) => Construct.mk(
        Option.type(dataType),
        Dict({
          dataTypeID: Type.lit(dataType),
          valueID: UnionTag.mk(someID, value),
        }),
      );

  static Object noneExpr(Object dataType) => Literal.mk(Option.type(dataType), Option.mk());
}

abstract class Result {
  static const dataTypeID = ID.constant(
      id: '3aaa05ca-9874-4c92-805b-764a2282a34f', hashCode: 198448261, label: 'dataType');

  static const valueID =
      ID.constant(id: '95f72c79-afd0-42cb-8169-4655e267b79d', hashCode: 43477464, label: 'value');

  static const okID =
      ID.constant(id: '5c25b177-d312-4766-adfa-10d31476e1a9', hashCode: 158842468, label: 'ok');

  static const errorID =
      ID.constant(id: '71879f42-3c5c-426f-913f-99a33a145fdd', hashCode: 297337715, label: 'error');

  static const typeDefID =
      ID.constant(id: '76537380-58bc-4f71-9254-5c303f3abbba', hashCode: 226558687, label: 'Result');

  static final def = TypeDef.record(
    'Result',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      valueID: TypeTree.union('value', {
        okID: TypeTree.mk('ok', Var.mk(dataTypeID)),
        errorID: TypeTree.mk('error', Type.lit(text)),
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
    Object result, {
    required T Function(Object) ok,
    required T Function(String) error,
  }) {
    final value = (result as Dict)[valueID].unwrap!;
    return UnionTag.tag(value) == okID
        ? ok(UnionTag.value(value))
        : error(UnionTag.value(value) as String);
  }

  static Object flatMap(Object result, Object Function(Object) f, [String errCtx = '']) =>
      cases(result, ok: (val) => f(val), error: (err) => Result.mkErr(err.wrap(errCtx)));

  static Object map(Object result, Object Function(Object) f, [String errCtx = '']) =>
      flatMap(result, (v) => Result.mkOk(f(v)), errCtx);

  static Object wrapErr(Object result, String errCtx) => map(result, (_) => _, errCtx);

  static Object flatten(Object result, [String errCtx = '']) =>
      cases(result, ok: (result) => result, error: (err) => Result.mkErr(err.wrap(errCtx)));

  static Object unwrap(Object result, [Object Function(String)? onErr]) =>
      cases(result, ok: (v) => v, error: (err) => onErr != null ? onErr(err) : throw Exception());

  static bool isOk(Object result) => Result.cases(result, ok: (_) => true, error: (_) => false);

  static Object mkOk(Object value) => Dict({
        valueID: UnionTag.mk(okID, value),
      });

  static Object mkErr(String msg) => Dict({
        valueID: UnionTag.mk(errorID, msg),
      });

  static Object okExpr(Object dataType, Object value) => Construct.mk(
        Option.type(dataType),
        Dict({
          dataTypeID: Type.lit(dataType),
          valueID: UnionTag.mk(okID, value),
        }),
      );

  static Object errExpr(Object dataType, String msg) =>
      Literal.mk(Result.type(dataType), mkErr(msg));
}

abstract class Expr {
  static const dataTypeID = ID.constant(
      id: '2127875b-fdc0-41f4-b12b-8842ad8a3fc5', hashCode: 125573506, label: 'dataType');

  static const typeCheckID = ID.constant(
      id: 'fab53ccf-34c7-4c11-bca8-4db900cd8dcd', hashCode: 452264354, label: 'typeCheck');

  static const typeCheckArgID = ID.constant(
      id: 'bc235d0c-a356-43ea-a1ed-8eb734c62faa', hashCode: 186591319, label: 'typeCheckArg');

  static const reduceID =
      ID.constant(id: '0a53bc15-7a95-452f-8b5a-cfc1739d8183', hashCode: 417204557, label: 'reduce');

  static const reduceArgID = ID.constant(
      id: 'd67a7d35-48b5-45c5-a745-657fd050a6f7', hashCode: 292873807, label: 'reduceArg');

  static const evalExprID = ID.constant(
      id: '43dd13e9-a834-420a-b0f2-4b116c6a0d9b', hashCode: 343615493, label: 'evalExpr');

  static const evalExprArgID = ID.constant(
      id: '1959f3ec-9584-4e9d-9d03-c41e875ac9c0', hashCode: 128012697, label: 'evalExprArg');

  static const interfaceID =
      ID.constant(id: '882c6c97-b16d-453c-bc15-14ac344bf9f1', hashCode: 64328690, label: 'Expr');

  static final interfaceDef = InterfaceDef.record(
    'ExprInterface',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      typeCheckID: TypeTree.mk(
        'typeCheck',
        Fn.typeExpr(
          argID: typeCheckArgID,
          argType: Var.mk(dataTypeID),
          returnType: Type.lit(Result.type(typeExprType)),
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

  static const implID =
      ID.constant(id: '26adcf86-e1bc-4e6b-b78e-b96abaa28d64', hashCode: 269157767, label: 'impl');

  static const dataID =
      ID.constant(id: '711313fd-932e-4e62-ac56-9eba135798af', hashCode: 473650145, label: 'data');

  static const _defID = ID.constant(
      id: '92529509-1da1-47b4-bb9d-7f8e00f46e97', hashCode: 521436227, label: 'ExprData');

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
  static GetCursor<Object> mkCursor({required GetCursor<Object> data, required Object impl}) =>
      Dict.cursor({dataID: data, implID: GetCursor(impl)});

  static Object mkExpr({required Object data, required Object impl}) =>
      Construct.mk(Expr.type, Dict({dataID: data, implID: impl}));

  static Object data(Object expr) => (expr as Dict)[dataID].unwrap!;
  static Object impl(Object expr) => (expr as Dict)[implID].unwrap!;

  static Object typeCheckFn = FnExpr.from(
    argID: const ID.constant(id: '776d4a07-c4c0-40e8-85b2-48fcf02be57d', hashCode: 101041817),
    argName: 'expr',
    argType: Type.lit(Expr.type),
    returnType: (_) => Type.lit(Result.type(typeExprType)),
    body: (arg) => FnApp.mk(
      RecordAccess.mk(RecordAccess.mk(arg, implID), typeCheckID),
      RecordAccess.mk(arg, dataID),
    ),
  );

  static Object reduceFn = FnExpr.from(
    argID: const ID.constant(id: '9ebd140a-24a5-42fa-aaad-35bb4796cfe4', hashCode: 49431941),
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
  static const typeID =
      ID.constant(id: 'de0040cf-1f5c-436c-977c-59819da7a2a5', hashCode: 442255260, label: 'type');

  static const itemsID =
      ID.constant(id: 'f697f2d8-63d2-4e8f-aea3-747778a3b752', hashCode: 419227200, label: 'items');

  static const typeDefID =
      ID.constant(id: '86eba6ed-fef9-4489-918c-4941c1801c17', hashCode: 38374837, label: 'List');

  static final def = TypeDef.record(
    'List',
    {
      typeID: TypeTree.mk('type', Type.lit(Type.type)),
      itemsID: TypeTree.unit('items'),
    },
    id: typeDefID,
    comptime: [typeID],
  );

  static const mkExprTypeDefID =
      ID.constant(id: '92d36ef8-49f0-446f-a981-5ab5918cf787', hashCode: 241917088, label: 'mkExpr');

  static const mkTypeID =
      ID.constant(id: '26e75d84-8f82-4422-9e27-363b6020a71c', hashCode: 349088087, label: 'mkType');

  static const mkValuesID = ID.constant(
      id: 'd4235672-f280-4a7c-b11e-2e85ae6959f3', hashCode: 104139111, label: 'mkValues');

  static final exprTypeDef = TypeDef.record(
    'MkList',
    {
      mkTypeID: TypeTree.mk('type', Type.lit(Expr.type)),
      mkValuesID: TypeTree.mk('mkValues', Type.lit(List.type(Expr.type))),
    },
    id: mkExprTypeDefID,
  );
  static final mkExprType = Type.mk(mkExprTypeDefID);

  static final _typeFn = langInverseFnMap[_mkListTypeCheck]!;

  static final _reduceFn = langInverseFnMap[_mkListReduce]!;

  static final _evalFn = langInverseFnMap[_mkListEval]!;

  static const implDefID =
      ID.constant(id: 'd2d4e3e8-7eb0-4580-bd86-fa7e958c7d40', hashCode: 365836427);
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
  static GetCursor<Object> mkCursor(GetCursor<Vec> values) => Dict.cursor({itemsID: values});

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

abstract class OrderedMap {
  static const keyID =
      ID.constant(id: 'b8bc1e54-d150-41e4-b63b-d548f895accf', hashCode: 450527056, label: 'key');

  static const valueID =
      ID.constant(id: '17626e5b-133e-4aef-979c-e7b42d95ee4e', hashCode: 410810779, label: 'value');

  static const keyOrderID = ID.constant(
      id: '7fa6f7f5-aeba-4569-be16-392decda0015', hashCode: 385489906, label: 'keyOrder');

  static const valueMapID = ID.constant(
      id: '8e273d0a-91d0-46bb-b584-ef07c80d69f3', hashCode: 239896861, label: 'valueMap');

  static final def = TypeDef.record(
    'OrderedMap',
    {
      keyID: TypeTree.mk('key', Type.lit(Type.type)),
      valueID: TypeTree.mk('value', Type.lit(Type.type)),
      keyOrderID: TypeTree.mk('keyOrder', List.typeExpr(Var.mk(keyID))),
      valueMapID: TypeTree.mk('valueMap', Map.typeExpr(Var.mk(keyID), Var.mk(valueID))),
    },
    comptime: [keyID, valueID],
    id: const ID.constant(id: '953d00a7-2287-458b-8ae4-ea7a39a60df7', hashCode: 323861333),
  );

  static Object type(Object key, Object value) => TypeDef.asType(def, properties: [
        MemberHas.mkEquals([keyID], Type.type, key),
        MemberHas.mkEquals([valueID], Type.type, value),
      ]);
  static Object typeExpr(Object key, Object value) => Type.mkExpr(TypeDef.id(def), properties: [
        MemberHas.mkEqualsExpr([keyID], Type.lit(Type.type), key),
        MemberHas.mkEqualsExpr([valueID], Type.lit(Type.type), value),
      ]);

  static Object mk(dart.List<Object> keys, dart.List<Object> values) =>
      Dict({keyOrderID: List.mk(keys), valueMapID: Map.mk(dart.Map.fromIterables(keys, values))});

  static Object keyOrder(Object orderedMap) => (orderedMap as Dict)[keyOrderID].unwrap!;
  static Object valueMap(Object orderedMap) => (orderedMap as Dict)[valueMapID].unwrap!;
}

abstract class Map {
  static const keyID =
      ID.constant(id: 'd530c2c0-cf24-4def-80bb-ebcab95d2d5f', hashCode: 294905267, label: 'key');

  static const valueID =
      ID.constant(id: 'ab5ffa2c-281b-46aa-8603-e61b019caced', hashCode: 274708939, label: 'value');

  static const entriesID = ID.constant(
      id: '8d9c47f4-a98f-4244-8931-de9d80b410ad', hashCode: 369787388, label: 'entries');

  static final def = TypeDef.record(
    'Map',
    {
      keyID: TypeTree.mk('key', Type.lit(Type.type)),
      valueID: TypeTree.mk('value', Type.lit(Type.type)),
      entriesID: TypeTree.mk('entries', Type.lit(unit)),
    },
    comptime: [keyID, valueID],
    id: const ID.constant(id: '376258e5-bf48-4ced-b71d-cbdd91778f73', hashCode: 310697086),
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
  static GetCursor<Object> mkCursor(dart.Map<Object, GetCursor<Object>> values) =>
      Dict.cursor({entriesID: Dict.cursor(values)});

  static const mkExprID =
      ID.constant(id: '3ae0055e-6dd0-4b05-99bc-59d1c84e80ea', hashCode: 468893412, label: 'mkExpr');

  static const mkKeyID =
      ID.constant(id: '9d915b46-613e-4dac-8506-c8441ef1c749', hashCode: 410566295, label: 'mkKey');

  static const mkValueID = ID.constant(
      id: '5b914784-cc28-49e5-bf9d-20c51b732003', hashCode: 356481698, label: 'mkValue');

  static const mkEntriesID = ID.constant(
      id: '34ba3fa8-c05b-4065-8574-60ff1af8a690', hashCode: 360165744, label: 'mkValues');

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

  static const mkExprImplDefID =
      ID.constant(id: '670cb618-686f-48f9-85a5-731ddf72d405', hashCode: 93616803);
  static final mkExprImpl = Expr.mkImpl(
    dataType: mkType,
    argName: 'mkMapData',
    typeCheckBody: langInverseFnMap[_mkMapTypeCheck]!,
    reduceBody: langInverseFnMap[_mkMapReduce]!,
    evalBody: langInverseFnMap[_mkMapEval]!,
  );
  static Object mkExpr(Type key, Type value, Object entries) => Expr.mk(
        impl: mkExprImpl,
        data: Dict({mkKeyID: key, mkValueID: value, mkEntriesID: entries}),
      );

  static Dict entries(Object map) => (map as Dict)[entriesID].unwrap! as Dict;
}

abstract class Any {
  static const typeID =
      ID.constant(id: '334ebc93-c233-4bb0-b2c2-924d17dc416a', hashCode: 211223142, label: 'type');

  static const valueID =
      ID.constant(id: 'ea44ba9e-777d-4bb8-b94c-5fa98162e17b', hashCode: 82992540, label: 'value');

  static const anyTypeID =
      ID.constant(id: 'e177aaf9-298e-4367-a404-36e5ceb7aec3', hashCode: 496085763, label: 'Any');

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

final textDef = TypeDef.unit(
  'Text',
  id: const ID.constant(id: '86290c47-720e-4f1b-8a70-ff70a6a0e6f7', hashCode: 416510342),
);
final text = TypeDef.asType(textDef);
final numberDef = TypeDef.unit(
  'Number',
  id: const ID.constant(id: '7fa75f16-9300-4c40-a278-7542888ed46e', hashCode: 461660923),
);
final number = TypeDef.asType(numberDef);
final booleanDef = TypeDef.unit(
  'Boolean',
  id: const ID.constant(id: 'e6e9e479-4d47-4877-905f-c40550db497b', hashCode: 14476584),
);
final boolean = TypeDef.asType(booleanDef);
final unitDef = TypeDef.unit(
  'Unit',
  id: const ID.constant(id: 'd6560fde-7408-457c-87e9-972dece2a19b', hashCode: 240639897),
);
final unit = TypeDef.asType(unitDef);
const unitValue = Dict();
final unitExpr = Literal.mk(unit, unitValue);
final bottomDef = TypeDef.mk(
  TypeTree.union('Bottom', const {}),
  id: const ID.constant(id: '7d3fe3b3-a851-44e6-966d-f5d8b4a63532', hashCode: 485841715),
);
final bottom = TypeDef.asType(bottomDef);
final typeExprType = Expr.type;

abstract class Fn {
  static const argIDID =
      ID.constant(id: 'e0f8fa96-7976-439e-b543-ded405a4edc7', hashCode: 18372969, label: 'argID');

  static const argNameID = ID.constant(
      id: 'b9f2073e-046e-4ad1-a1c4-4728a8784cc4', hashCode: 461342352, label: 'argName');

  static const argTypeID = ID.constant(
      id: '223d6028-ab69-4868-ada7-a23679c12bc2', hashCode: 317191343, label: 'argType');

  static const returnTypeID = ID.constant(
      id: 'b152248e-1873-472d-9586-37b6864a9001', hashCode: 363697882, label: 'returnType');

  static const bodyID =
      ID.constant(id: 'da6ffa1b-be44-4b5b-b45c-c13a1a47edc5', hashCode: 379211532, label: 'body');

  static const palID =
      ID.constant(id: '3cb76cc3-7297-4f96-8855-29ddd301e218', hashCode: 245631161, label: 'pal');

  static const dartID =
      ID.constant(id: 'a245a56a-629a-4ec7-90b2-57bf63cfcf53', hashCode: 308967378, label: 'dart');

  static const closureID = ID.constant(
      id: '67f7d923-a797-4a6f-b12d-44d5555fb54c', hashCode: 485558102, label: 'closure');

  static const typeDefID =
      ID.constant(id: '02f689e0-259f-4c27-875e-06a2ba099732', hashCode: 423091995, label: 'Fn');

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

  static GetCursor<Object> mkCursor({
    required GetCursor<Object> argID,
    required GetCursor<Object> argName,
    required GetCursor<Object> body,
    GetCursor<Object>? closure,
  }) =>
      Dict.cursor({
        argIDID: argID,
        argNameID: argName,
        bodyID: body,
        closureID: closure ?? GetCursor(List.mk(const [])),
      });

  static Object mkDartBody(ID body) => UnionTag.mk(dartID, body);
  static Object mkPalBody(Object expr) => UnionTag.mk(palID, expr);
  static GetCursor<Object> mkPalBodyCursor(GetCursor<Object> expr) =>
      UnionTag.mkCursor(palID, expr);

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
  static const argIDID =
      ID.constant(id: '1c4f4632-41d4-4fbe-bf6b-5b6317c66016', hashCode: 528009573, label: 'argID');

  static const argNameID = ID.constant(
      id: 'c6b799cd-3240-48b8-bede-3b60fb925524', hashCode: 113566933, label: 'argName');

  static const argTypeID = ID.constant(
      id: 'fdc8f600-ca92-4681-8311-4a8512c37848', hashCode: 358506794, label: 'argType');

  static const returnTypeID = ID.constant(
      id: '189a5098-1e38-483c-b7c0-c057f6cb546a', hashCode: 459530872, label: 'returnType');

  static const bodyID =
      ID.constant(id: '3fa52748-5ec5-427d-868b-2cc7d37e869a', hashCode: 218356751, label: 'body');

  static const palID =
      ID.constant(id: '1f42b336-4d83-4852-a374-044eefb8ef88', hashCode: 37792295, label: 'pal');

  static const dartID =
      ID.constant(id: '9431f585-4d0b-4f23-86d6-5dbe43329a8a', hashCode: 337895974, label: 'dart');

  static const typeDefID =
      ID.constant(id: '2d8e9bbf-7e8d-4b0d-ad65-01298d69bd00', hashCode: 299706980, label: 'FnExpr');

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

  static const exprImplID = ID.constant(
      id: '72f25cd4-d719-4be4-90b6-a4843ce5a357', hashCode: 382784284, label: 'FnExprImpl');

  static final typeFnBody = langInverseFnMap[_fnExprTypeCheck]!;

  static final reduceFnBody = langInverseFnMap[_fnExprReduce]!;

  static final evalFnBody = langInverseFnMap[_fnExprEval]!;

  static final Object exprImpl = Expr.mkImpl(
    dataType: type,
    argName: 'fnData',
    typeCheckBody: typeFnBody,
    reduceBody: reduceFnBody,
    evalBody: evalFnBody,
  );

  static Object _mk({
    required ID argID,
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
          argIDID: argID,
          bodyID: body,
        }),
      );

  static GetCursor<Object> _mkCursor({
    required GetCursor<Object> argID,
    required GetCursor<Object> argName,
    required GetCursor<Object> argType,
    GetCursor<Object>? returnType,
    required GetCursor<Object> body,
  }) =>
      Expr.mkCursor(
        impl: exprImpl,
        data: Dict.cursor({
          argTypeID: argType,
          returnTypeID: Option.mkCursor(returnType),
          argNameID: argName,
          argIDID: argID,
          bodyID: body,
        }),
      );

  static Object pal({
    required ID argID,
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

  static GetCursor<Object> mkPalCursor({
    required GetCursor<Object> argID,
    required GetCursor<Object> argName,
    required GetCursor<Object> argType,
    required GetCursor<Object> returnType,
    required GetCursor<Object> body,
  }) =>
      _mkCursor(
        argID: argID,
        argName: argName,
        argType: argType,
        returnType: returnType,
        body: UnionTag.mkCursor(palID, body),
      );

  static Object palInferred({
    required ID argID,
    required String argName,
    required Object argType,
    required Object body,
  }) =>
      _mk(argID: argID, argName: argName, argType: argType, body: UnionTag.mk(palID, body));

  static Object dart({
    required ID argID,
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
    required ID argID,
    required String argName,
    required Object argType,
    required Object Function(Object) returnType,
    required Object Function(Object) body,
  }) {
    return FnExpr.pal(
      argID: argID,
      argName: argName,
      argType: argType,
      returnType: returnType(Var.mk(argID)),
      body: body(Var.mk(argID)),
    );
  }

  static GetCursor<Object> mkFromCursor({
    required GetCursor<Object> argID,
    required GetCursor<Object> argName,
    required GetCursor<Object> argType,
    required GetCursor<Object> Function(GetCursor<Object>) returnType,
    required GetCursor<Object> Function(GetCursor<Object>) body,
  }) =>
      FnExpr.mkPalCursor(
        argID: argID,
        argName: argName,
        argType: argType,
        returnType: returnType(Var.mkCursor(argID)),
        body: body(Var.mkCursor(argID)),
      );

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
  static const fnID =
      ID.constant(id: 'a1f3e9db-a5e3-4aa8-a1ed-edbe7f373975', hashCode: 388278076, label: 'fn');

  static const argID =
      ID.constant(id: '23794c3f-fb84-4436-8936-cdf84cc6e75c', hashCode: 208294906, label: 'arg');

  static final typeDef = TypeDef.mk(
    TypeTree.record('FnApp', {
      fnID: TypeTree.mk('fn', Type.lit(Expr.type)),
      argID: TypeTree.mk('arg', Type.lit(Expr.type)),
    }),
    id: const ID.constant(id: '947c0aea-b58e-4034-8512-0838670fae12', hashCode: 466578475),
  );
  static final type = TypeDef.asType(typeDef);

  static final _typeFnBody = langInverseFnMap[_fnAppTypeCheck]!;
  static final _reduceFnBody = langInverseFnMap[_fnAppReduce]!;
  static final _evalFnBody = langInverseFnMap[_fnAppEval]!;

  static const exprImplDefID =
      ID.constant(id: '41246aa9-a53a-47ab-8013-cddb2c3373b9', hashCode: 150028507);

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
  final String? msg;

  const MyException([this.msg]);

  @override
  String toString() {
    return 'MyException(${msg ?? ""})';
  }

  static T throwFn<T>([String? msg]) => throw MyException(msg);
}

abstract class Construct extends Expr {
  static const dataTypeID = ID.constant(
      id: 'f2af00a9-68c6-4e63-81e5-8b1e05b1a580', hashCode: 185504088, label: 'dataType');

  static const treeID =
      ID.constant(id: '3bbab571-41f4-4067-8c23-361717f48376', hashCode: 90096316, label: 'tree');

  static const typeDefID = ID.constant(
      id: '8f215b60-9628-44d0-a7e6-978ffb30a809', hashCode: 379539543, label: 'Construct');

  static final typeDef = TypeDef.record(
    'Construct',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      treeID: TypeTree.mk('tree', Type.lit(unit)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final _typeFn = langInverseFnMap[_constructTypeCheck]!;

  static final _reduceFn = langInverseFnMap[_constructReduce]!;

  static final _evalFn = langInverseFnMap[_constructEval]!;

  static const exprImplID = ID.constant(
      id: 'e105db48-0324-4752-9cb8-1775a5fda623', hashCode: 362074369, label: 'ConstructExprImpl');

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
  static const targetID =
      ID.constant(id: '78d7b456-495f-4639-a804-bf02758eded5', hashCode: 134990006, label: 'target');
  static const memberID =
      ID.constant(id: 'b9bc2f9a-90a7-4b64-901b-f869be227f1c', hashCode: 312702729, label: 'member');
  static const typeDefID = ID.constant(
      id: '4d63f23f-91a6-4280-835c-da2c5e5b81fb', hashCode: 379045543, label: 'RecordAccess');

  static final typeDef = TypeDef.record(
    'RecordAccess',
    {
      targetID: TypeTree.mk('target', Type.lit(Expr.type)),
      memberID: TypeTree.mk('accessed', Type.lit(ID.type)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final _typeFn = langInverseFnMap[_recordAccessTypeCheck]!;

  static final _reduceFn = langInverseFnMap[_recordAccessReduce]!;

  static final _evalFn = langInverseFnMap[_recordAccessEval]!;

  static const exprImplID = ID.constant(
      id: '25be335f-6ffb-4646-a7cb-116ebc621b26', hashCode: 46621241, label: 'exprImpl');

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
  static const typeID =
      ID.constant(id: '401b9a0a-a910-4ffd-af4e-3e6cc1a063f6', hashCode: 194142071, label: 'type');

  static const valueID =
      ID.constant(id: 'c4394ba1-d3bf-411b-ad56-71a1ec7c55ec', hashCode: 307972573, label: 'value');

  static const typeDefID = ID.constant(
      id: '7e79a0e2-1e9f-4525-ad10-cdf96cc31db8', hashCode: 308912535, label: 'Literal');

  static final typeDef = TypeDef.record(
    'Literal',
    {
      typeID: TypeTree.mk('type', Type.lit(Type.type)),
      valueID: TypeTree.mk('value', Var.mk(typeID)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final _typeFnData = langInverseFnMap[_literalTypeCheck]!;

  static final _reduceFnData = langInverseFnMap[_literalReduce]!;

  static final _evalFnData = langInverseFnMap[_literalEval]!;

  static const exprImplID = ID.constant(
      id: '547c97d7-6434-4fae-a6b4-cf6b4277424e', hashCode: 491904096, label: 'LiteralExprImpl');

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
  static GetCursor<Object> mkCursor(GetCursor<Object> type, GetCursor<Object> value) =>
      Expr.mkCursor(
        impl: exprImpl,
        data: Dict.cursor({typeID: type, valueID: value}),
      );

  static Object getType(Object literal) => (literal as Dict)[typeID].unwrap!;
  static Object getValue(Object literal) => (literal as Dict)[valueID].unwrap!;
}

abstract class Var extends Expr {
  static const IDID =
      ID.constant(id: '05d8fb98-de4e-4c86-a452-3368c950fa3f', hashCode: 190872692, label: 'ID');

  static const typeDefID =
      ID.constant(id: 'd1a06451-22f0-4c9f-9f39-4814920519f6', hashCode: 502452118, label: 'Var');

  static final typeDef = TypeDef.record(
    'Var',
    {
      IDID: TypeTree.mk('id', Type.lit(ID.type)),
    },
    id: typeDefID,
  );
  static final type = Type.mk(typeDefID);

  static final _typeFn = langInverseFnMap[_varTypeCheck]!;
  static final _reduceFn = langInverseFnMap[_varReduce]!;
  static final _evalFn = langInverseFnMap[_varEval]!;

  static const exprImplDefID =
      ID.constant(id: '7aef8101-2fa8-40e7-9575-a91d2595d978', hashCode: 389287988);
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
  static GetCursor<Object> mkCursor(GetCursor<Object> varID) => Expr.mkCursor(
        impl: exprImpl,
        data: Dict.cursor({IDID: varID}),
      );

  static ID id(Object varAccess) => (varAccess as Dict)[IDID].unwrap! as ID;
}

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

  Object getInterface(ID id) => Option.unwrap(Binding.value(this, Option.unwrap(getBinding(id))));

  Object getImpl(ID id) => Option.unwrap(Binding.value(this, Option.unwrap(getBinding(id))));
}

abstract class Binding {
  static const IDID =
      ID.constant(id: 'a639d23e-3412-45d1-af06-07e67fdb2071', hashCode: 117891622, label: 'ID');

  static const valueTypeID =
      ID.constant(id: 'cd6a590a-2ec6-445f-b83f-1761a8688b73', hashCode: 79187658, label: 'type');

  static const nameID =
      ID.constant(id: '9a2bce74-a540-4b04-aaea-29bd6bf0a804', hashCode: 403676171, label: 'name');

  static const reducedValueID = ID.constant(
      id: '16e6361e-f9a8-46dc-99d2-a5975e36591b', hashCode: 159780296, label: 'reducedValue');

  static const valueID =
      ID.constant(id: 'f28e3b67-77c6-495f-afd5-de9eb338c355', hashCode: 16595567, label: 'value');

  static final def = TypeDef.record(
    'Binding',
    {
      IDID: TypeTree.mk('id', Type.lit(ID.type)),
      valueTypeID: TypeTree.mk('type', Type.lit(typeExprType)),
      nameID: TypeTree.mk('name', Type.lit(text)),
      reducedValueID: TypeTree.mk(
        'reducedValue',
        Type.lit(
          Fn.type(
            argID: const ID.constant(
                id: 'f165b09a-b66c-4d9c-8e1b-8123c16db64d', hashCode: 376240261, label: '_'),
            argType: unit,
            returnType: Type.lit(Option.type(Expr.type)),
          ),
        ),
      ),
      valueID: TypeTree.mk(
        'value',
        Type.lit(
          Fn.type(
            argID: const ID.constant(
                id: '5764d758-7d64-47fc-8adb-43cee7eb5e53', hashCode: 97531497, label: '_'),
            argType: unit,
            returnType: Option.typeExpr(Var.mk(valueTypeID)),
          ),
        ),
      ),
    },
    id: const ID.constant(id: '86b55176-3b8d-4032-a001-80dd3e2667f7', hashCode: 72800204),
  );
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
        nameID: (Ctx _) => name,
        reducedValueID: (Ctx _) => Option.mk(reducedValue),
        valueID: (Ctx _) => Option.mk(value),
      });

  static Object mkLazy({
    required ID id,
    required Object Function(Ctx)? type,
    required String Function(Ctx) name,
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
  static String name(Ctx ctx, Object binding) =>
      ((binding as Dict)[nameID].unwrap! as String Function(Ctx))(ctx);
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
  Ctx withoutBinding(ID id) => withElement(
        BindingCtx(
          (get<BindingCtx>() ?? const BindingCtx()).bindings.remove(id),
        ),
      );
  Object getBinding(ID id) =>
      Option.mk((get<BindingCtx>() ?? const BindingCtx()).bindings[id].unwrap);
  Iterable<Object> get getBindings => (get<BindingCtx>() ?? const BindingCtx()).bindings.values;
}

const _substBindingID =
    ID.constant(id: 'a1d4fe69-012e-4b69-9ea6-ad2bdd6694c6', hashCode: 529898823, label: 'subst');
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

Object assignableErr(
  Ctx ctx,
  Object a,
  Object b,
  String errCtx,
  Object Function() ifAssignable,
) =>
    assignableErrFlat(ctx, a, b, errCtx, () => Result.mkOk(ifAssignable()));

Object assignableErrFlat(
  Ctx ctx,
  Object a,
  Object b,
  String errContext,
  Object Function() ifAssignable,
) {
  if (assignableImpl(_initSubst(ctx), a, b)) {
    return ifAssignable();
  } else {
    final msg =
        'expected:\n  ${palPrint(ctx, Expr.type, a)}\nactual:\n  ${palPrint(ctx, Expr.type, b)}';
    return Result.mkErr(
      errContext.isEmpty ? msg : '$errContext:\n${msg.indent}',
    );
  }
}

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
          // TODO: temporary hack til subtyping can be configured properly
          if (List.iterate(pathA).last == Fn.argIDID) continue;
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
      return true;
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
      varSubst(ctx, fromID, toID, List.mkExprDataType(exprData)),
      [...List.iterate(List.mkExprValues(exprData)).map((e) => varSubst(ctx, fromID, toID, e))],
    );
  } else {
    throw UnimplementedError('subst on expr type $exprType');
  }
}

Object dispatch(Ctx ctx, ID interfaceID, Object type) {
  final dispatchCache = Option.unwrap(Binding.value(
    ctx,
    Option.unwrap(ctx.getBinding(InterfaceDef.dispatchCacheID(interfaceID))),
  )) as dart.Map<Object, Object>;
  if (dispatchCache.containsKey(type)) return Option.mk(dispatchCache[type]!);

  Object? bestImpl;
  Object? bestArgType;
  Object? bestArg;
  Object? bestType;
  for (final binding in ctx.getBindings) {
    if (!ImplDef.bindingIDPrefixForID(interfaceID).isPrefixOf(Binding.id(binding))) continue;
    final bindingRawType = Binding.valueType(ctx, binding);
    if (!Result.isOk(bindingRawType)) continue;
    final bindingFnType = Result.unwrap(bindingRawType);
    final bindingType = Literal.getValue(
      Expr.data(
        Type.exprMemberEquals(ctx, bindingFnType, [Fn.returnTypeID]),
      ),
    );
    final argType = Literal.getValue(
      Expr.data(Type.exprMemberEquals(ctx, bindingFnType, [Fn.argTypeID])),
    );
    ctx = ctx.withBinding(Binding.mk(
      id: ImplDef.definitionArgID,
      type: Result.mkOk(Type.lit(argType)),
      name: 'definitionArg',
    ));
    final subst = assignableSubst(ctx, bindingType, Type.lit(type));
    if (subst == null) continue;
    if (bestType != null) {
      if (assignable(
        ctx,
        bindingType,
        varSubst(ctx, ImplDef.definitionArgID, ID.mk().append(ImplDef.definitionArgID), bestType),
      )) continue;

      if (!assignable(
        ctx,
        bestType,
        varSubst(
            ctx, ImplDef.definitionArgID, ID.mk().append(ImplDef.definitionArgID), bindingType),
      )) return Option.mk();
    }
    bestArgType = argType;
    bestType = bindingType;
    bestImpl = Option.unwrap(Binding.value(ctx, binding));
    bestArg = _extractSubstArg(ctx, argType, subst);
  }
  // TODO: the type in the literal is wrong but it doesn't rly matter
  if (bestImpl == null) {
    return Option.mk();
  } else {
    final actualImpl = eval(ctx, FnApp.mk(Literal.mk(bestArgType!, bestImpl), bestArg!));
    dispatchCache[type] = actualImpl;
    return Option.mk(actualImpl);
  }
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
          type: Result.mkOk(Type.lit(dataType)),
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

const _visitedID =
    ID.constant(id: '809f3010-4527-422a-9384-560f655008e5', hashCode: 455052035, label: 'visited');
Ctx updateVisited(Ctx ctx, ID id) {
  final prevSet = Option.cases(
    ctx.getBinding(_visitedID),
    some: (visitedBinding) => Option.unwrap(Binding.value(ctx, visitedBinding)) as Set,
    none: () => const Set(),
  );
  if (prevSet.contains(id)) throw const MyException('ahhh cycle!');
  return ctx.withBinding(
    Binding.mk(
      id: _visitedID,
      name: 'visited',
      type: null,
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
    final keys = arg.keys.map((k) {
      return reified.Pair(k, k is ID ? _toEncodable(k) as String : serialize(k, ''));
    }).toList();
    mergeSort(
      keys,
      compare: (k1, k2) => k1.second.compareTo(k2.second),
    );
    return {for (final key in keys) key.second: arg[key.first].unwrap!};
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
    return Dict(arg
        .map((key, dynamic value) => MapEntry(_revive(key) as Object, _revive(value) as Object)));
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
  Ctx withFnMaps(dart.List<FnMap> maps) => withElement(
        FnMapCtx({
          if (get<FnMapCtx>() != null) ...get<FnMapCtx>()!.fnMap,
          for (final map in maps) ...map
        }),
      );

  Object Function(Ctx, Object) getFn(ID id) => get<FnMapCtx>()!.fnMap[id]!;
  String getFnName(ID id) =>
      get<FnMapCtx>()!.fnMap.keys.firstWhere((k) => k == id, orElse: () => ID.fake).label!;
}

const coreModuleID =
    ID.constant(id: '24a202de-8089-42a8-b81b-de92efb34d9b', hashCode: 443982851, label: 'core');

@DartFn('71220800-2abd-40c3-b97a-5b8b1b743e6f')
Object _varEval(Ctx ctx, Object arg) {
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
}

@DartFn('6c0432ae-e016-4c21-9579-2e8c6e15412d')
Object _varReduce(Ctx ctx, Object arg) {
  return Option.cases(
    ctx.getBinding(Var.id(arg)),
    none: () => Var.mk(Var.id(arg)),
    some: (binding) => Option.cases(
      Binding.value(
        ctx,
        binding,
      ),
      some: (val) => Literal.mk(
        Literal.getValue(Expr.data(Result.unwrap(Binding.valueType(ctx, binding)))),
        val,
      ),
      none: () => Option.cases(
        Binding.reducedValue(ctx, binding),
        some: (reducedValue) => reduce(ctx, reducedValue),
        none: () => Var.mk(Var.id(arg)),
      ),
    ),
  );
}

@DartFn('3e9ec939-8b06-4ae1-b994-6d9ffce15b61')
Object _varTypeCheck(Ctx ctx, Object arg) {
  return Option.cases(
    ctx.getBinding(Var.id(arg)),
    some: (binding) => Result.map(
      Binding.valueType(ctx, binding),
      (_) => _,
      'var ${Binding.name(ctx, binding)} doesn\'t type check',
    ),
    none: () => Result.mkErr('unknown var ${Var.id(arg)}'),
  );
}

@DartFn('e53622ea-9e07-48c1-bcb2-3376ae9eb0f5')
Object _literalEval(Ctx ctx, Object arg) => Literal.getValue(arg);
@DartFn('407672c9-89c1-4c56-ae90-61114500136a')
Object _literalReduce(Ctx ctx, Object arg) => Expr.mk(impl: Literal.exprImpl, data: arg);
@DartFn('5249e346-b160-4a03-b657-2002027596be')
Object _literalTypeCheck(Ctx ctx, Object arg) => Result.mkOk(Type.lit(Literal.getType(arg)));
@DartFn('e0018149-0f3c-4ddd-bcef-9c681cee4ddd')
Object _recordAccessEval(Ctx ctx, Object data) {
  return (eval(ctx, RecordAccess.target(data)) as Dict)[RecordAccess.member(data)].unwrap!;
}

@DartFn('9685059c-a3b5-4964-882d-107151dc7802')
Object _recordAccessReduce(Ctx ctx, Object data) {
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
}

@DartFn('82bf53a9-470a-4a7c-9326-e367397c56d4')
Object _recordAccessTypeCheck(Ctx ctx, Object arg) {
  return Result.flatMap(
    typeCheck(ctx, RecordAccess.target(arg)),
    (targetTypeExpr) {
      if (Expr.dataType(targetTypeExpr) == Literal.type) {
        final targetType = Literal.getValue(Expr.data(targetTypeExpr));
        final targetTypeDef = ctx.getType(Type.id(targetType));
        final path = Type.path(targetType);
        final treeAt = TypeTree.treeAt(TypeDef.tree(targetTypeDef), List.iterate(path));
        return TypeTree.treeCases(
          treeAt,
          leaf: (_) => Result.mkErr(
            'tried to access member ${RecordAccess.member(arg)} on leaf node of type ${TypeTree.name(TypeDef.tree(targetTypeDef))}!',
          ),
          union: (_) => Result.mkErr('record access on union!'),
          record: (recordNode) {
            final member = RecordAccess.member(arg);
            final subTree = recordNode[member].unwrap!;
            return TypeTree.treeCases(
              subTree,
              record: (_) => Result.mkOk(
                Type.lit((targetType as Dict).put(Type.pathID, List.add(path, member))),
              ),
              union: (_) => Result.mkOk(
                Type.lit((targetType as Dict).put(Type.pathID, List.add(path, member))),
              ),
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
                          type: Result.mkOk(Type.lit(Equals.dataType(value))),
                          name: TypeTree.name(typeTree),
                          value: Equals.equalTo(value),
                        ),
                        none: () {
                          return Binding.mkLazy(
                            id: path.last as ID,
                            name: (_) => TypeTree.name(typeTree),
                            type: (ctx) => Result.mkOk(reduce(ctx, leaf)),
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
                return Result.map(typeCheck(ctx, leafNode), (_) => reduce(ctx, leafNode));
              },
            );
          },
        );
      } else {
        return Result.mkErr(
          'typechecking record access on non-literal target type not implemented!',
        );
      }
    },
  );
}

@DartFn('ff147616-dbb9-4759-9184-5aa800572852')
Object _constructEval(Ctx ctx, Object arg) {
  final typeDef = ctx.getType(Type.id(Construct.dataType(arg)));
  final comptimeIDs = TypeDef.comptime(typeDef);
  return TypeTree.maybeMapData(
    TypeDef.tree(typeDef),
    Construct.tree(arg),
    (_, dataLeaf, path) => Option.mk(comptimeIDs.contains(path.last) ? null : eval(ctx, dataLeaf)),
  );
}

@DartFn('7a0fc27e-4511-463e-bc56-1445de7d65a8')
Object _constructReduce(Ctx ctx, Object arg) {
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
}

@DartFn('3b12dfa7-b5d6-4bf3-bc0f-47efdb9e46ce')
Object _constructTypeCheck(Ctx origCtx, Object arg) {
  final typeDef = origCtx.getType(Type.id(Construct.dataType(arg)));

  final computedProps = <Object>[];
  DartList lazyBindings(Object typeTree, Object dataTree, Object path) {
    return TypeTree.treeCases(
      typeTree,
      record: (record) {
        if (record.length != (dataTree as Dict).length) {
          throw const MyException('construct tree shape does not match type');
        }
        return [
          ...record.entries.expand((entry) {
            if (!dataTree.containsKey(entry.key)) {
              throw const MyException('construct tree shape does not match type');
            }
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
        if (!union.containsKey(tag)) {
          throw const MyException('construct tree shape does not match type');
        }
        return lazyBindings(union[tag].unwrap!, UnionTag.value(dataTree), List.add(path, tag));
      },
      leaf: (leaf) {
        Object? lazyType;
        Object? lazyValue;
        computeType(Ctx ctx) {
          if (lazyType == null) {
            final typeCheckTypeDef = Result.flatMap(
              typeCheck(updateVisited(ctx, List.iterate(path).last as ID), leaf),
              (checkedType) => assignableErr(
                ctx,
                Type.lit(Type.type),
                checkedType,
                'type tree leaf expr is not a type',
                () => unit,
              ),
              'type tree leaf expr doesn\'t type check',
            );
            lazyType = Result.flatMap(
              typeCheckTypeDef,
              (_) => Result.flatMap(
                typeCheck(origCtx, dataTree),
                (dataType) => assignableErr(
                  ctx,
                  reduce(updateVisited(ctx, List.iterate(path).last as ID), leaf),
                  dataType,
                  'construct data doesn\'t match',
                  () => dataType,
                ),
                'construct data doesn\'t type check',
              ),
            );
          }
          return lazyType!;
        }

        computeValue(Ctx ctx) {
          if (lazyValue == null) {
            final dataType = Result.unwrap(computeType(ctx));
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
            name: (_) => TypeTree.name(typeTree),
            type: computeType,
            reducedValue: computeValue,
          ),
        ];
      },
    );
  }

  try {
    final bindings = lazyBindings(TypeDef.tree(typeDef), Construct.tree(arg), List.mk(const []));
    final typeCtx = bindings.fold<Ctx>(origCtx, (ctx, binding) => ctx.withBinding(binding));
    for (final binding in bindings) {
      final typeResult = Binding.valueType(typeCtx, binding);
      if (!Result.isOk(typeResult)) {
        return Result.wrapErr(typeResult, 'construct failed');
      }
    }
  } on MyException catch (e) {
    return Result.mkErr(e.msg ?? '');
  }

  return Result.mkOk(
    reduce(origCtx, Type.mkExpr(Type.id(Construct.dataType(arg)), properties: computedProps)),
  );
}

@DartFn('bb3a9958-31b9-4309-9113-5bbda9b7da19')
Object _fnAppEval(Ctx ctx, Object data) {
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
}

@DartFn('64923943-f567-44dd-afb9-bf8a28ea7719')
Object _fnAppReduce(Ctx ctx, Object fnApp) {
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
              type: Result.mkOk(Literal.mk(
                Type.type,
                Type.memberEquals(Literal.getType(Expr.data(reducedFn)), [Fn.argTypeID]),
              )),
              reducedValue: reduce(ctx, FnApp.arg(fnApp)),
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
              type: Result.mkOk(reduce(ctx, FnExpr.argType(fnExpr))),
              reducedValue: reduce(ctx, FnApp.arg(fnApp)),
            )),
            bodyExpr,
          );
        },
        dart: (_) => Expr.mk(impl: FnApp.exprImpl, data: fnApp),
      );
    }
  }
  return Expr.mk(impl: FnApp.exprImpl, data: fnApp);
}

@DartFn('be6e4c77-a9fb-4d10-92cc-338c59ec3d5b')
Object _fnAppTypeCheck(Ctx ctx, Object fnApp) {
  return Result.flatMap(
    typeCheck(ctx, FnApp.fn(fnApp)),
    (fnTypeExpr) {
      if ({Literal.type, Construct.type}.contains(Expr.dataType(fnTypeExpr))) {
        return Result.flatMap(
          typeCheck(ctx, FnApp.arg(fnApp)),
          (argType) => assignableErr(
            ctx,
            Type.exprMemberEquals(ctx, fnTypeExpr, [Fn.argTypeID]),
            argType,
            'fn argument doesn\'t match expected type',
            () {
              final argID = Literal.getValue(
                Expr.data(
                  Type.exprMemberEquals(ctx, fnTypeExpr, [Fn.argIDID]),
                ),
              ) as ID;
              ctx = ctx.withBinding(
                Binding.mk(
                  id: argID,
                  type: Result.mkOk(argType),
                  name: argID.label ?? '$argID',
                  reducedValue: reduce(ctx, FnApp.arg(fnApp)),
                ),
              );
              return reduce(
                ctx,
                Literal.getValue(
                  Expr.data(Type.exprMemberEquals(ctx, fnTypeExpr, [Fn.returnTypeID])),
                ),
              );
            },
          ),
        );
      } else {
        return Result.mkErr('type check fn app where fnType isn\'t literal not yet implemented!');
      }
    },
  );
}

@DartFn('738cb307-4b48-4bf2-907b-e06e1e42a49a')
Object _fnExprEval(Ctx ctx, Object arg) {
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
}

@DartFn('a814d41c-2b9b-49a0-afc2-9c6c25e47468')
Object _fnExprReduce(Ctx ctx, Object fnData) => Expr.mk(impl: FnExpr.exprImpl, data: fnData);

@DartFn('916ccdd7-75de-4c37-b728-a318b101aff7')
Object _fnExprTypeCheck(Ctx ctx, Object fn) {
  return Result.flatMap(
    typeCheck(ctx, FnExpr.argType(fn)),
    (argTypeType) {
      if (!assignable(ctx, Type.lit(Type.type), argTypeType)) {
        return Result.mkErr('fn expr arg type expr is not a type');
      }
      final argType = reduce(ctx, FnExpr.argType(fn));
      ctx = ctx.withBinding(
        Binding.mk(
          id: FnExpr.argID(fn),
          type: Result.mkOk(argType),
          name: FnExpr.argName(fn),
        ),
      );
      return Option.cases(
        FnExpr.returnType(fn),
        none: () => FnExpr.bodyCases(
          fn,
          dart: (_) => Result.mkErr('dart Fn w no declared return type not allowed!'),
          pal: (body) => Result.map(
            typeCheck(ctx, body),
            (bodyType) {
              if (Expr.dataType(argType) != Literal.type) {
                // TODO: would like to reduce but causes loop w TypeProperty.mkExpr rn
                return Fn.typeExpr(
                  argID: FnExpr.argID(fn),
                  argType: argType,
                  returnType: bodyType,
                );
              } else {
                return Literal.mk(
                  Type.type,
                  Fn.type(
                    argID: FnExpr.argID(fn),
                    argType: Literal.getValue(Expr.data(argType)),
                    returnType: bodyType,
                  ),
                );
              }
            },
          ),
        ),
        some: (returnTypeExpr) => Result.flatMap(
          typeCheck(ctx, returnTypeExpr),
          (returnTypeType) => assignableErrFlat(
            ctx,
            Type.lit(Type.type),
            returnTypeType,
            'return type not a type',
            () {
              final returnType = reduce(ctx, returnTypeExpr);
              return FnExpr.bodyCases(
                fn,
                pal: (body) => Result.flatMap(
                  typeCheck(ctx, body),
                  (bodyType) => assignableErr(
                    ctx,
                    returnType,
                    bodyType,
                    'fn expr body not assignable to return type',
                    // TODO: weird logic here around expr wrapping in FnValue.types?
                    () => reduce(
                      ctx,
                      Fn.typeExpr(
                        argID: FnExpr.argID(fn),
                        argType: argType,
                        returnType: returnType,
                      ),
                    ),
                  ),
                ),
                // TODO: typecheck arg & return type exprs
                dart: (_) => Result.mkOk(reduce(
                  ctx,
                  Fn.typeExpr(argID: FnExpr.argID(fn), argType: argType, returnType: returnType),
                )),
              );
            },
          ),
        ),
      );
    },
  );
}

@DartFn('19e1d36f-81f1-4c8e-bfc5-69cbde60bd8a')
Object _mkMapEval(Ctx ctx, Object arg) => Dict({
      for (final entry in List.iterate((arg as Dict)[Map.mkEntriesID].unwrap!))
        eval(ctx, List.iterate(entry).first): eval(ctx, List.iterate(entry).skip(1).first)
    });

@DartFn('7fa732c0-a61d-4e43-94e4-c4fafe04d254')
Object _mkMapReduce(Ctx ctx, Object arg) {
  throw Exception('reduce map expr not yet implemented!');
}

@DartFn('7f2c7445-867b-4d44-afae-040ee700bff6')
Object _mkMapTypeCheck(Ctx ctx, Object arg) {
  final keyType = (arg as Dict)[Map.mkKeyID].unwrap!;
  final valueType = arg[Map.mkValueID].unwrap!;

  for (final entry in List.iterate(arg[Map.mkEntriesID].unwrap!)) {
    if (typeCheck(ctx, List.iterate(entry).first) != Result.mkOk(keyType)) {
      return Result.mkErr('map key does not match key type');
    }
    if (typeCheck(ctx, List.iterate(entry).skip(1).first) != Result.mkOk(valueType)) {
      return Result.mkErr('map value does not match value type');
    }
  }
  return Result.mkOk(Map.type(keyType, valueType));
}

@DartFn('d755250f-c583-4d96-84da-f4c0a6bdd823')
Object _mkListEval(Ctx ctx, Object arg) => List.mk(
      [...List.iterate((arg as Dict)[List.mkValuesID].unwrap!).map((expr) => eval(ctx, expr))],
    );

@DartFn('6600af92-b24d-4e65-8b78-35d9ba9d8b12')
Object _mkListReduce(Ctx ctx, Object arg) {
  bool nonLit = false;
  final reducedSubExprs = <Object>[];
  for (final subExpr in [
    List.mkExprDataType(arg),
    ...List.iterate((arg as Dict)[List.mkValuesID].unwrap!)
  ]) {
    final reduced = reduce(ctx, subExpr);
    if (Expr.dataType(reduced) != Literal.type) nonLit = true;
    reducedSubExprs.add(reduced);
  }
  if (nonLit) return List.mkExpr(reducedSubExprs.first, [...reducedSubExprs.skip(1)]);
  final lits = reducedSubExprs.map(Expr.data).map(Literal.getValue);
  return Literal.mk(
    List.type(lits.first),
    List.mk([...lits.skip(1)]),
  );
}

@DartFn('6c67f06e-cbe0-4a46-a7e4-c04ee77eb3e1')
Object _mkListTypeCheck(Ctx ctx, Object arg) {
  final maybeListValueType = Result.flatMap(
    typeCheck(ctx, List.mkExprDataType(arg)),
    (type) => assignableErr(
      ctx,
      Type.lit(Type.type),
      type,
      'list expression element type isn\'t a type',
      () => reduce(ctx, List.mkExprDataType(arg)),
    ),
  );
  if (!Result.isOk(maybeListValueType)) return maybeListValueType;
  final listValueType = Result.unwrap(maybeListValueType);
  for (final value in List.iterate(List.mkExprValues(arg))) {
    final valueType = typeCheck(ctx, value);
    final mapError = Result.cases(
      valueType,
      error: (msg) => Result.mkErr('list value doesn\' type check because $msg'),
      ok: (type) {
        if (!assignable(ctx, listValueType, type)) {
          return Result.mkErr('list value not assignable to list type');
        } else {
          return Result.mkOk(type);
        }
      },
    );
    if (!Result.isOk(mapError)) return mapError;
  }
  if (Expr.dataType(listValueType) == Literal.type) {
    return Result.mkOk(Type.lit(List.type(Literal.getValue(Expr.data(listValueType)))));
  } else {
    return Result.mkOk(List.typeExpr(listValueType));
  }
}

final textAppendFnExpr = FnExpr.dart(
  argID: ID.mk(),
  argName: '_',
  argType: Type.lit(List.type(text)),
  returnType: Type.lit(text),
  body: langInverseFnMap[_textAppend]!,
);
@DartFn('4c67f06e-cbe0-4a46-a7e4-c04ee77eb3e1')
Object _textAppend(Ctx ctx, Object arg) {
  return List.iterate(arg).join();
}

extension Indent on String {
  String get indent => splitMapJoin('\n', onNonMatch: (s) => s.padLeft(2));
  String wrap(String ctx) => ctx.isEmpty ? this : '$ctx:\n$indent';
}

extension PalGetCursorAccess on GetCursor<Object> {
  GetCursor<Object> operator [](Object id) => this.cast<Dict>()[id].whenPresent;
}

extension PalCursorAccess on Cursor<Object> {
  Cursor<Object> operator [](Object id) => this.cast<Dict>()[id].whenPresent;
}
