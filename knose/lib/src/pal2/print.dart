import 'package:ctx/ctx.dart';
import 'package:knose/annotations.dart';
import 'package:knose/src/pal2/lang.dart';

part 'print.g.dart';

abstract class Printable {
  static const dataTypeID = ID.constant(
      id: '0ede4654-f0b0-47ed-a856-012c292a46f2', hashCode: 363298241, label: 'dataType');
  static const printID =
      ID.constant(id: '926e4d43-3f78-4fc5-b6aa-d6f4a2ab5853', hashCode: 411444004, label: 'print');
  static const printArgID =
      ID.constant(id: '8a1c6dec-1993-4e90-afee-63c2db3bff0f', hashCode: 150960822, label: 'print');
  static final interfaceDef = InterfaceDef.record(
    'Printable',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      printID: TypeTree.mk(
        'print',
        Fn.typeExpr(
          argID: printArgID,
          argType: Var.mk(dataTypeID),
          returnType: Type.lit(text),
        ),
      ),
    },
    id: const ID.constant(id: 'fd7cb66a-b70d-4165-b675-51133faed6ba', hashCode: 19279715),
  );

  static Object mkImpl({required ID id, required Object dataType, required ID print}) => ImplDef.mk(
        id: id,
        implemented: InterfaceDef.id(interfaceDef),
        definition: Dict({
          dataTypeID: Type.lit(dataType),
          printID: FnExpr.dart(
            argID: printArgID,
            argName: 'printArg',
            argType: Type.lit(dataType),
            returnType: Type.lit(text),
            body: print,
          ),
        }),
      );

  static Object mkParameterizedImpl({
    required ID id,
    required String name,
    required Object argType,
    required Object Function(Object) dataType,
    required ID print,
  }) =>
      ImplDef.mkParameterized(
        id: id,
        implemented: InterfaceDef.id(interfaceDef),
        argType: argType,
        definition: (arg) => Dict({
          dataTypeID: dataType(arg),
          printID: FnExpr.pal(
            argID: printArgID,
            argName: 'printArg',
            argType: dataType(arg),
            returnType: Type.lit(text),
            body: FnApp.mk(
              FnExpr.dart(
                argID: const ID.constant(
                    id: '733cfd40-e86d-45de-8639-b1e82570e945', hashCode: 344043086),
                argName: 'printArg',
                argType: Type.lit(Any.type),
                returnType: Type.lit(text),
                body: print,
              ),
              Any.mkExpr(dataType(arg), Var.mk(printArgID)),
            ),
          )
        }),
      );

  static const printFnID =
      ID.constant(id: '0043f7c5-fcc8-466e-b575-25eb6a1a4fd1', hashCode: 25799240, label: 'print');
  static const moduleID =
      ID.constant(id: 'd522e29d-bff9-45d8-b017-0021330d2474', hashCode: 236908208, label: 'print');
  static final module = Module.mk(id: moduleID, name: 'Print', definitions: [
    InterfaceDef.mkDef(interfaceDef),
    ValueDef.mk(
      id: printFnID,
      name: 'print',
      value: FnExpr.dart(
        argID: const ID.constant(id: 'cdcbd002-6fde-4783-abaf-b8f9cf896c55', hashCode: 536055723),
        argName: 'object',
        argType: Type.lit(Any.type),
        returnType: Type.lit(text),
        body: printInverseFnMap[_printFn]!,
      ),
    ),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'Default',
      argType: Type.type,
      dataType: (typeArg) => typeArg,
      print: printInverseFnMap[_defaultFn]!,
      id: const ID.constant(id: 'a91f54c0-894d-4658-b2ce-f1173c587a27', hashCode: 511135028),
    )),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'List',
      argType: Type.type,
      dataType: (typeArg) => List.typeExpr(typeArg),
      print: printInverseFnMap[_listFn]!,
      id: const ID.constant(id: 'e658adf0-12ba-419e-9af3-ebb8cd33101f', hashCode: 190298448),
    )),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'Map',
      argType: Pair.type(Type.type, Type.type),
      dataType: (typeArg) => Map.typeExpr(
        RecordAccess.mk(typeArg, Pair.firstID),
        RecordAccess.mk(typeArg, Pair.secondID),
      ),
      print: printInverseFnMap[_mapFn]!,
      id: const ID.constant(id: 'd8a6923b-5f19-438a-983b-ae817776f2b3', hashCode: 378268881),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Type.type,
      print: printInverseFnMap[_typeFn]!,
      id: const ID.constant(id: '04893f0a-dcd6-4f2b-b35b-2ca0b0b6e1d9', hashCode: 366776310),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: number,
      print: printInverseFnMap[_numberFn]!,
      id: const ID.constant(id: 'e8614674-88fc-4d07-98f5-9a9a2a73d536', hashCode: 499492708),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: text,
      print: printInverseFnMap[_textFn]!,
      id: const ID.constant(id: 'b347e6fe-0491-44ba-bffd-68bebf3ad390', hashCode: 500290122),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: TypeProperty.type,
      print: printInverseFnMap[_typePropFn]!,
      id: const ID.constant(id: '21c5302f-66ea-4232-a59e-95bc71b54e5d', hashCode: 327841775),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: MemberHas.type,
      print: printInverseFnMap[_memberHasFn]!,
      id: const ID.constant(id: '57517694-5c5d-499d-8428-46e93ef2badf', hashCode: 342624459),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Equals.type,
      print: printInverseFnMap[_equalsFn]!,
      id: const ID.constant(id: 'b7241f5d-740f-4e13-98ac-3e17089612e7', hashCode: 496252195),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Expr.type,
      print: printInverseFnMap[_exprFn]!,
      id: const ID.constant(id: '4145c6f8-facf-4422-9f04-c7196feef7b8', hashCode: 62292771),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: ID.type,
      print: printInverseFnMap[_idFn]!,
      id: const ID.constant(id: 'bd1614d2-c7e8-47f8-8863-437fbff525f9', hashCode: 478363742),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Var.type,
      print: printInverseFnMap[_varFn]!,
      id: const ID.constant(id: 'b1e00a92-c704-40b8-8ca2-726e76cdc97b', hashCode: 449000542),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Literal.type,
      print: printInverseFnMap[_literalFn]!,
      id: const ID.constant(id: 'e9b4df23-adb5-416e-8dad-0011b306b9db', hashCode: 287598169),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Construct.type,
      print: printInverseFnMap[_constructFn]!,
      id: const ID.constant(id: 'ca5036fc-b545-4c73-a56e-dd4e1082da13', hashCode: 61827497),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: List.mkExprType,
      print: printInverseFnMap[_listExprFn]!,
      id: const ID.constant(id: 'e6a39c55-e3bf-4ca8-8539-11ab3111cd91', hashCode: 128755319),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: FnApp.type,
      print: printInverseFnMap[_fnAppFn]!,
      id: const ID.constant(id: 'c8c7cddd-0d6f-47b2-9da2-f7f54b10ba3a', hashCode: 370936441),
    )),
  ]);

  @DartFn('0a433255-e890-48a8-b649-bdc5c8683101')
  static Object _printFn(Ctx ctx, Object arg) {
    final impl = Option.unwrap(
      dispatch(
        ctx,
        InterfaceDef.id(interfaceDef),
        InterfaceDef.implType(interfaceDef, [
          MemberHas.mkEquals([dataTypeID], Type.type, Any.getType(arg))
        ]),
      ),
    );

    final dataType = (impl as Dict)[dataTypeID].unwrap!;
    return eval(
      ctx,
      FnApp.mk(
        Literal.mk(
          Fn.type(argID: printArgID, argType: dataType, returnType: Type.lit(text)),
          impl[printID].unwrap!,
        ),
        Literal.mk(dataType, Any.getValue(arg)),
      ),
    );
  }

  @DartFn('13c11c7e-b549-45e5-8625-dc87846d000a')
  static Object _defaultFn(Ctx ctx, Object arg) {
    final typeArg = Any.getType(arg);
    final data = Any.getValue(arg);
    final typeDef = ctx.getType(Type.id(typeArg));

    String recurse(Ctx ctx, Object typeTree, Object dataTree) {
      return TypeTree.treeCases(
        typeTree,
        record: (record) {
          return record
              .mapValues((k, v) {
                final child = recurse(ctx, v, (dataTree as Dict)[k].unwrap!);
                final wrappedChild = TypeTree.treeCases(
                  v,
                  record: (_) => '{$child}',
                  union: (_) => child,
                  leaf: (_) => child,
                );
                return '${TypeTree.name(v)}: $wrappedChild';
              })
              .values
              .join(", ");
        },
        union: (union) {
          final subTree = union[UnionTag.tag(dataTree)].unwrap!;
          return '${TypeTree.name(subTree)}(${recurse(ctx, subTree, UnionTag.value(dataTree))})';
        },
        leaf: (leaf) => palPrint(ctx, eval(ctx, leaf), dataTree),
      );
    }

    final tree = TypeDef.tree(typeDef);
    final augmentedValue = TypeTree.augmentTree(typeArg, data);
    final dataBindings = TypeTree.dataBindings(tree, augmentedValue);
    final resultString = recurse(
      dataBindings.fold(
        ctx,
        (ctx, binding) => ctx.withBinding(binding),
      ),
      tree,
      augmentedValue,
    );
    return '${TypeTree.name(tree)}($resultString)';
  }

  @DartFn('6b85c52c-5c8f-4f52-ab8f-88872a7e2c1c')
  static Object _listFn(Ctx ctx, Object arg) {
    final listType = Any.getType(arg);
    final data = Any.getValue(arg);
    final memberType = Type.memberEquals(listType, [List.typeID]);
    return '[${List.iterate(data).map((elem) => palPrint(ctx, memberType, elem)).join(", ")}]';
  }

  @DartFn('462d6740-375a-4054-b140-c7d42bc84e35')
  static Object _mapFn(Ctx ctx, Object arg) {
    final mapType = Any.getType(arg);
    final data = Any.getValue(arg);
    final keyType = Type.memberEquals(mapType, [Map.keyID]);
    final valueType = Type.memberEquals(mapType, [Map.valueID]);
    return '{${Map.entries(data).entries.map((entry) => "${palPrint(ctx, keyType, entry.key)}: ${palPrint(ctx, valueType, entry.value)}").join(", ")}}';
  }

  @DartFn('ce7456bd-6ca6-400d-9f6c-b5413624812a')
  static Object _typeFn(Ctx ctx, Object type) {
    final tree = TypeDef.tree(ctx.getType(Type.id(type)));
    final name = TypeTree.name(tree);
    final props =
        List.iterate(Type.properties(type)).map((prop) => palPrint(ctx, TypeProperty.type, prop));
    final suffix = props.isEmpty ? '' : '<${props.join(", ")}>';
    return '$name$suffix';
  }

  @DartFn('2d7f0fe7-deaf-45e0-871a-375d5843d904')
  static Object _numberFn(Ctx _, Object number) => '$number';
  @DartFn('969a93c8-3470-4908-9a98-d8dd9881a274')
  static Object _textFn(Ctx _, Object text) => '"$text"';
  @DartFn('b1b4d796-cd0a-4b8b-8ca2-1cf0363d47d4')
  static Object _typePropFn(Ctx ctx, Object prop) =>
      palPrint(ctx, TypeProperty.dataType(prop), TypeProperty.data(prop));
  @DartFn('4d779f78-c8e9-4144-a69f-9696f71647e1')
  static Object _memberHasFn(Ctx ctx, Object memberHas) =>
      List.iterate(MemberHas.path(memberHas)).map((id) => (id as ID).label ?? id.id).join('.') +
      palPrint(ctx, TypeProperty.type, MemberHas.property(memberHas));
  @DartFn('e0eb9e74-d730-4f8d-9de5-5305c435d715')
  static Object _equalsFn(Ctx ctx, Object equals) =>
      ' = ${palPrint(ctx, Equals.dataType(equals), Equals.equalTo(equals))}';
  @DartFn('8917399b-78d9-4d2d-9e8e-3c420aef3b54')
  static Object _exprFn(Ctx ctx, Object expr) =>
      palPrint(ctx, Expr.dataType(expr), Expr.data(expr));
  @DartFn('b5418a3c-c0ce-431c-bd6c-885a6aed3712')
  static Object _idFn(Ctx ctx, Object id) => '$id';
  @DartFn('57d1377c-16ea-4bce-8e91-e34742321815')
  static Object _varFn(Ctx ctx, Object varData) => Option.cases(
        ctx.getBinding(Var.id(varData)),
        some: (binding) => Binding.name(binding),
        none: () => Var.id(varData).label ?? 'Var(${palPrint(ctx, ID.type, Var.id(varData))}',
      );
  @DartFn('05dfa958-82fb-48b6-9a93-66f9882af5fb')
  static Object _literalFn(Ctx ctx, Object literalData) => palPrint(
        ctx,
        Literal.getType(literalData),
        Literal.getValue(literalData),
      );

  @DartFn('13c11c7f-b549-45e5-8625-dc87846d000a')
  static Object _constructFn(Ctx ctx, Object construct) {
    final typeDef = ctx.getType(Type.id(Construct.dataType(construct)));

    String recurse(Ctx ctx, Object typeTree, Object dataTree) {
      return TypeTree.treeCases(
        typeTree,
        record: (record) {
          return record
              .mapValues((k, v) {
                final child = recurse(ctx, v, (dataTree as Dict)[k].unwrap!);
                final wrappedChild = TypeTree.treeCases(
                  v,
                  record: (_) => '{$child}',
                  union: (_) => child,
                  leaf: (_) => child,
                );
                return '${TypeTree.name(v)}: $wrappedChild';
              })
              .values
              .join(", ");
        },
        union: (union) {
          final subTree = union[UnionTag.tag(dataTree)].unwrap!;
          return '${TypeTree.name(subTree)}(${recurse(ctx, subTree, UnionTag.value(dataTree))})';
        },
        leaf: (leaf) => palPrint(ctx, Expr.type, dataTree),
      );
    }

    final tree = TypeDef.tree(typeDef);
    final resultString = recurse(
      ctx,
      tree,
      Construct.tree(construct),
    );
    return '${TypeTree.name(tree)}.mk($resultString)';
  }

  @DartFn('12c11c7f-b549-45e5-8625-dc87846d000a')
  static Object _listExprFn(Ctx ctx, Object listExpr) =>
      palPrint(ctx, List.type(Expr.type), List.mkExprValues(listExpr));

  @DartFn('12c11c7f-b549-45e5-8625-da87846d000a')
  static Object _fnAppFn(Ctx ctx, Object fnApp) {
    final fnString = palPrint(ctx, Expr.type, FnApp.fn(fnApp));
    final argString = palPrint(ctx, Expr.type, FnApp.arg(fnApp));
    if (Expr.dataType(FnApp.fn(fnApp)) == Var.type) {
      return '$fnString($argString)';
    }
    return 'apply($fnString, $argString)';
  }

  static final fnMap = printFnMap;
}

String palPrint(Ctx ctx, Object type, Object value) =>
    eval(ctx, FnApp.mk(Var.mk(Printable.printFnID), Literal.mk(Any.type, Any.mk(type, value))))
        as String;
