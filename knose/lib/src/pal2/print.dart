import 'package:ctx/ctx.dart';
import 'package:knose/src/pal2/lang.dart';

abstract class Printable {
  static final dataTypeID = ID('dataType');
  static final printID = ID('print');
  static final printArgID = ID('print');
  static final interfaceDef = InterfaceDef.record('Printable', {
    dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
    printID: TypeTree.mk(
      'print',
      Fn.typeExpr(
        argID: printArgID,
        argType: Var.mk(dataTypeID),
        returnType: Type.lit(text),
      ),
    ),
  });

  static Object mkImpl({required Object dataType, required ID print}) => ImplDef.mk(
        id: ID(Type.id(dataType).label),
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
    required String name,
    required Object argType,
    required Object Function(Object) dataType,
    required ID print,
  }) =>
      ImplDef.mkParameterized(
        id: ID(name),
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

  static Object Function(Ctx, Object) mkParameterizedFwder(
    Object Function(Ctx, Object, Object) print,
  ) =>
      (ctx, any) => print(ctx, Any.getType(any), Any.getValue(any));

  static final printFnID = ID('print');
  static final module = Module.mk(name: 'Print', definitions: [
    InterfaceDef.mkDef(interfaceDef),
    ValueDef.mk(
      id: printFnID,
      name: 'print',
      value: FnExpr.dart(
        argName: 'object',
        argType: Type.lit(Any.type),
        returnType: Type.lit(text),
        body: const ID.from(id: '0a433255-e890-48a8-b649-bdc5c8683101'),
      ),
    ),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'Default',
      argType: Type.type,
      dataType: (typeArg) => typeArg,
      print: const ID.from(id: '13c11c7e-b549-45e5-8625-dc87846d000a'),
    )),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'List',
      argType: Type.type,
      dataType: (typeArg) => List.typeExpr(typeArg),
      print: const ID.from(id: '6b85c52c-5c8f-4f52-ab8f-88872a7e2c1c'),
    )),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'Map',
      argType: Pair.type(Type.type, Type.type),
      dataType: (typeArg) => Map.typeExpr(
        RecordAccess.mk(typeArg, Pair.firstID),
        RecordAccess.mk(typeArg, Pair.secondID),
      ),
      print: const ID.from(id: '462d6740-375a-4054-b140-c7d42bc84e35'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Type.type,
      print: const ID.from(id: 'ce7456bd-6ca6-400d-9f6c-b5413624812a'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: number,
      print: const ID.from(id: '2d7f0fe7-deaf-45e0-871a-375d5843d904'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: text,
      print: const ID.from(id: '969a93c8-3470-4908-9a98-d8dd9881a274'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: TypeProperty.type,
      print: const ID.from(id: 'b1b4d796-cd0a-4b8b-8ca2-1cf0363d47d4'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: MemberHas.type,
      print: const ID.from(id: '4d779f78-c8e9-4144-a69f-9696f71647e1'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Equals.type,
      print: const ID.from(id: 'e0eb9e74-d730-4f8d-9de5-5305c435d715'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Expr.type,
      print: const ID.from(id: '8917399b-78d9-4d2d-9e8e-3c420aef3b54'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: ID.type,
      print: const ID.from(id: 'b5418a3c-c0ce-431c-bd6c-885a6aed3712'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Var.type,
      print: const ID.from(id: '57d1377c-16ea-4bce-8e91-e34742321815'),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Literal.type,
      print: const ID.from(id: '05dfa958-82fb-48b6-9a93-66f9882af5fb'),
    )),
  ]);

  static final FnMap fnMap = {
    const ID.from(id: '0a433255-e890-48a8-b649-bdc5c8683101'): (ctx, arg) {
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
    },
    const ID.from(id: '13c11c7e-b549-45e5-8625-dc87846d000a'): mkParameterizedFwder(
      (ctx, typeArg, data) {
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
      },
    ),
    const ID.from(id: '6b85c52c-5c8f-4f52-ab8f-88872a7e2c1c'): mkParameterizedFwder(
      (ctx, listType, data) {
        final memberType = Type.memberEquals(listType, [List.typeID]);
        return '[${List.iterate(data).map((elem) => palPrint(ctx, memberType, elem)).join(", ")}]';
      },
    ),
    const ID.from(id: '462d6740-375a-4054-b140-c7d42bc84e35'): mkParameterizedFwder(
      (ctx, mapType, data) {
        final keyType = Type.memberEquals(mapType, [Map.keyID]);
        final valueType = Type.memberEquals(mapType, [Map.valueID]);
        return '{${Map.entries(data).entries.map((entry) => "${palPrint(ctx, keyType, entry.key)}: ${palPrint(ctx, valueType, entry.value)}").join(", ")}}';
      },
    ),
    const ID.from(id: 'ce7456bd-6ca6-400d-9f6c-b5413624812a'): (ctx, type) {
      final tree = TypeDef.tree(ctx.getType(Type.id(type)));
      final name = TypeTree.name(tree);
      final props =
          List.iterate(Type.properties(type)).map((prop) => palPrint(ctx, TypeProperty.type, prop));
      final suffix = props.isEmpty ? '' : '<${props.join(", ")}>';
      return '$name$suffix';
    },
    const ID.from(id: '2d7f0fe7-deaf-45e0-871a-375d5843d904'): (_, number) => '$number',
    const ID.from(id: '969a93c8-3470-4908-9a98-d8dd9881a274'): (_, text) => '"$text"',
    const ID.from(id: 'b1b4d796-cd0a-4b8b-8ca2-1cf0363d47d4'): (ctx, prop) =>
        palPrint(ctx, TypeProperty.dataType(prop), TypeProperty.data(prop)),
    const ID.from(id: '4d779f78-c8e9-4144-a69f-9696f71647e1'): (ctx, memberHas) =>
        List.iterate(MemberHas.path(memberHas)).map((id) => (id as ID).label ?? id.id).join('.') +
        palPrint(ctx, TypeProperty.type, MemberHas.property(memberHas)),
    const ID.from(id: 'e0eb9e74-d730-4f8d-9de5-5305c435d715'): (ctx, equals) =>
        ' = ${palPrint(ctx, Equals.dataType(equals), Equals.equalTo(equals))}',
    const ID.from(id: '8917399b-78d9-4d2d-9e8e-3c420aef3b54'): (ctx, expr) =>
        palPrint(ctx, Expr.dataType(expr), Expr.data(expr)),
    const ID.from(id: 'b5418a3c-c0ce-431c-bd6c-885a6aed3712'): (ctx, id) => '$id',
    const ID.from(id: '57d1377c-16ea-4bce-8e91-e34742321815'): (ctx, varData) => Option.cases(
          ctx.getBinding(Var.id(varData)),
          some: (binding) => Binding.name(binding),
          none: () => Var.id(varData).label ?? 'Var(${palPrint(ctx, ID.type, Var.id(varData))}',
        ),
    const ID.from(id: '05dfa958-82fb-48b6-9a93-66f9882af5fb'): (ctx, literalData) => palPrint(
          ctx,
          Literal.getType(literalData),
          Literal.getValue(literalData),
        ),
  };
}

String palPrint(Ctx ctx, Object type, Object value) =>
    eval(ctx, FnApp.mk(Var.mk(Printable.printFnID), Literal.mk(Any.type, Any.mk(type, value))))
        as String;
