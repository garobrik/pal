import 'package:ctx/ctx.dart';
import 'package:knose/annotations.dart';
import 'package:knose/src/pal2/lang.dart';

part 'print.g.dart';

abstract class Printable {
  static final dataTypeID = ID.mk('dataType');
  static final printID = ID.mk('print');
  static final printArgID = ID.mk('print');
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
        id: ID.mk(Type.id(dataType).label),
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
        id: ID.mk(name),
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

  static final printFnID = ID.mk('print');
  static final module = Module.mk(name: 'Print', definitions: [
    InterfaceDef.mkDef(interfaceDef),
    ValueDef.mk(
      id: printFnID,
      name: 'print',
      value: FnExpr.dart(
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
    )),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'List',
      argType: Type.type,
      dataType: (typeArg) => List.typeExpr(typeArg),
      print: printInverseFnMap[_listFn]!,
    )),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'Map',
      argType: Pair.type(Type.type, Type.type),
      dataType: (typeArg) => Map.typeExpr(
        RecordAccess.mk(typeArg, Pair.firstID),
        RecordAccess.mk(typeArg, Pair.secondID),
      ),
      print: printInverseFnMap[_mapFn]!,
    )),
    ImplDef.mkDef(mkImpl(dataType: Type.type, print: printInverseFnMap[_typeFn]!)),
    ImplDef.mkDef(mkImpl(dataType: number, print: printInverseFnMap[_numberFn]!)),
    ImplDef.mkDef(mkImpl(dataType: text, print: printInverseFnMap[_textFn]!)),
    ImplDef.mkDef(mkImpl(dataType: TypeProperty.type, print: printInverseFnMap[_typePropFn]!)),
    ImplDef.mkDef(mkImpl(dataType: MemberHas.type, print: printInverseFnMap[_memberHasFn]!)),
    ImplDef.mkDef(mkImpl(dataType: Equals.type, print: printInverseFnMap[_equalsFn]!)),
    ImplDef.mkDef(mkImpl(dataType: Expr.type, print: printInverseFnMap[_exprFn]!)),
    ImplDef.mkDef(mkImpl(dataType: ID.type, print: printInverseFnMap[_idFn]!)),
    ImplDef.mkDef(mkImpl(dataType: Var.type, print: printInverseFnMap[_varFn]!)),
    ImplDef.mkDef(mkImpl(dataType: Literal.type, print: printInverseFnMap[_literalFn]!)),
    ImplDef.mkDef(mkImpl(dataType: Construct.type, print: printInverseFnMap[_constructFn]!)),
    ImplDef.mkDef(mkImpl(dataType: List.mkExprType, print: printInverseFnMap[_listExprFn]!)),
    ImplDef.mkDef(mkImpl(dataType: FnApp.type, print: printInverseFnMap[_fnAppFn]!)),
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
