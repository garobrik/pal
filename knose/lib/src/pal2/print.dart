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

  static Object mkImpl({required Object dataType, required Object Function(Ctx, Object) print}) =>
      ImplDef.mk(
        id: ID(Type.id(dataType).label),
        implemented: InterfaceDef.id(interfaceDef),
        definition: Dict({
          dataTypeID: Type.lit(dataType),
          printID: FnExpr.dart(
            argID: printArgID,
            argName: 'printArg',
            argType: Type.lit(dataType),
            returnType: Type.lit(text),
            body: mkDartBodyID(print),
          ),
        }),
      );

  static Object mkParameterizedImpl({
    required String name,
    required Object argType,
    required Object Function(Object) dataType,
    required Object Function(Ctx, Object, Object) print,
  }) =>
      ImplDef.mkDart(
        id: ID(name),
        implemented: InterfaceDef.id(interfaceDef),
        argType: argType,
        returnType: (typeArgExpr) => InterfaceDef.implTypeExpr(interfaceDef, [
          MemberHas.mkEqualsExpr(
            [dataTypeID],
            Type.lit(Type.type),
            dataType(typeArgExpr),
          )
        ]),
        definition: (ctx, typeArgValue) {
          final dataTypeValue = eval(
            ctx,
            FnApp.mk(
              FnExpr.from(
                argName: 'typeArg',
                argType: Type.lit(argType),
                returnType: (_) => Type.lit(Type.type),
                body: (arg) => dataType(arg),
              ),
              Literal.mk(argType, typeArgValue),
            ),
          );
          return Dict({
            dataTypeID: dataTypeValue,
            printID: eval(
              ctx,
              FnExpr.dart(
                argID: printArgID,
                argName: 'data',
                argType: Type.lit(dataTypeValue),
                returnType: Type.lit(text),
                body: mkDartBodyID((ctx, data) => print(ctx, dataTypeValue, data)),
              ),
            ),
          });
        },
      );

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
        body: mkDartBodyID((ctx, arg) {
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
        }),
      ),
    ),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'Default',
      argType: Type.type,
      dataType: (typeArg) => typeArg,
      print: (ctx, typeArg, data) {
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
    )),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'List',
      argType: Type.type,
      dataType: (typeArg) => List.typeExpr(typeArg),
      print: (ctx, listType, data) {
        final memberType = Type.memberEquals(listType, [List.typeID]);
        return '[${List.iterate(data).map((elem) => palPrint(ctx, memberType, elem)).join(", ")}]';
      },
    )),
    ImplDef.mkDef(mkParameterizedImpl(
      name: 'Map',
      argType: Pair.type(Type.type, Type.type),
      dataType: (typeArg) => Map.typeExpr(
        RecordAccess.mk(typeArg, Pair.firstID),
        RecordAccess.mk(typeArg, Pair.secondID),
      ),
      print: (ctx, mapType, data) {
        final keyType = Type.memberEquals(mapType, [Map.keyID]);
        final valueType = Type.memberEquals(mapType, [Map.valueID]);
        return '{${Map.entries(data).entries.map((entry) => "${palPrint(ctx, keyType, entry.key)}: ${palPrint(ctx, valueType, entry.value)}").join(", ")}}';
      },
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Type.type,
      print: (ctx, type) {
        final tree = TypeDef.tree(ctx.getType(Type.id(type)));
        final name = TypeTree.name(tree);
        final props = List.iterate(Type.properties(type))
            .map((prop) => palPrint(ctx, TypeProperty.type, prop));
        final suffix = props.isEmpty ? '' : '<${props.join(", ")}>';
        return '$name$suffix';
      },
    )),
    ImplDef.mkDef(mkImpl(dataType: number, print: (_, number) => '$number')),
    ImplDef.mkDef(mkImpl(dataType: text, print: (_, text) => '"$text"')),
    ImplDef.mkDef(mkImpl(
      dataType: TypeProperty.type,
      print: (ctx, prop) => palPrint(ctx, TypeProperty.dataType(prop), TypeProperty.data(prop)),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: MemberHas.type,
      print: (ctx, memberHas) =>
          List.iterate(MemberHas.path(memberHas)).map((id) => (id as ID).label ?? id.id).join('.') +
          palPrint(ctx, TypeProperty.type, MemberHas.property(memberHas)),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Equals.type,
      print: (ctx, equals) =>
          ' = ${palPrint(ctx, Equals.dataType(equals), Equals.equalTo(equals))}',
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Expr.type,
      print: (ctx, expr) => palPrint(ctx, Expr.dataType(expr), Expr.data(expr)),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: ID.type,
      print: (ctx, id) => '$id',
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Var.type,
      print: (ctx, varData) => Option.cases(
        ctx.getBinding(Var.id(varData)),
        some: (binding) => Binding.name(binding),
        none: () => Var.id(varData).label ?? 'Var(${palPrint(ctx, ID.type, Var.id(varData))}',
      ),
    )),
    ImplDef.mkDef(mkImpl(
      dataType: Literal.type,
      print: (ctx, literalData) => palPrint(
        ctx,
        Literal.getType(literalData),
        Literal.getValue(literalData),
      ),
    )),
  ]);
}

String palPrint(Ctx ctx, Object type, Object value) =>
    eval(ctx, FnApp.mk(Var.mk(Printable.printFnID), Literal.mk(Any.type, Any.mk(type, value))))
        as String;

/*
def print(t: Type, value: t) => dispatch(Printable{dataType: t[=value]})
impl Vt: Type, Printable{dataType: t}
impl Vt: Type, Printable{dataType: List<t>}

print(t: List<number>, value: [1])
  => dispatch(Printable{dataType: List<number>[=[1]]})
  => super?(Vt: Type, Printable<dataType = t>, Printable<dataType = List<number>[=[1]]>)
    => Printable == Printable true
    => t > List<number>[=[1]] ??
    => true
  => super?(Vt: Type, Printable<dataType: Type<id = List.id, prop = MemberHas(dataType, Equals(var))>, Printable{dataType: List<number>[=[1]]})
    => Printable == Printable true
    => describes?(List<t>, List<number>[=[1]])
      => List == List true
      => t > number ??
      => true
    => true
  => super?(Vt: Type, Printable<dataType: t>, Vt: Type, Printable<dataType: List<t>>)
    => Printable == Printable true
    => t1 > List<t2> ??

lang basic exprs:
  - var
  - construct
  - mkList
  - lit

  assignable(lit, lit) => if (lit.type == Type) props_assignable(lit, lit) else lit == lit
  assignable(lit, any) => false
  assignable(var, any) => if (var in subst) assignable(subst[var], any) else if (any is var and any in subst) assignable(var, subst[any]) else if (var in any) false else ctx.subst[var] = any
  assignable(any, var) => false
  assignable(ctor, lit/ctor) => fields match && for field (variance_assignable(field.variance, field, ))
  assignable(list, list/lit) => length match && for elem (assignable(field, etc, etc))

  - fn
  - fn app
*/
