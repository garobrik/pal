import 'package:ctx/ctx.dart';
import 'package:knose/src/pal2/lang.dart';

abstract class Printable {
  static final dataTypeID = ID('dataType');
  static final printID = ID('print');
  static final printArgID = ID('print');
  static final interfaceDef = InterfaceDef.record('Printable', {
    dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    printID: TypeTree.mk(
      'print',
      Fn.typeExpr(
        argID: printArgID,
        argType: Var.mk(dataTypeID),
        returnType: Literal.mk(Type.type, text),
      ),
    ),
  });

  static Object mkImpl({required Object dataType, required Object Function(Ctx, Object) print}) =>
      ImplDef.mk(
        implemented: InterfaceDef.id(interfaceDef),
        definition: Dict({
          dataTypeID: Literal.mk(Type.type, dataType),
          printID: FnExpr.dart(
            argID: printArgID,
            argName: 'printArg',
            argType: Literal.mk(Type.type, dataType),
            returnType: Literal.mk(Type.type, text),
            body: print,
          ),
        }),
      );

  static Object mkParameterizedImpl({
    required Object argType,
    required Object Function(Object) dataType,
    required Object Function(Ctx, Object, Object) print,
  }) =>
      ImplDef.mkDart(
        implemented: InterfaceDef.id(interfaceDef),
        argType: argType,
        returnType: (typeArgExpr) => InterfaceDef.implTypeExpr(interfaceDef, [
          MemberHas.mkEqualsExpr(
            [dataTypeID],
            Literal.mk(Type.type, Type.type),
            dataType(typeArgExpr),
          )
        ]),
        definition: (ctx, typeArgValue) {
          final dataTypeValue = eval(
            ctx,
            FnApp.mk(
              FnExpr.from(
                argName: 'typeArg',
                argType: Literal.mk(Type.type, Type.type),
                returnType: (_) => Literal.mk(Type.type, Type.type),
                body: (arg) => dataType(arg),
              ),
              Literal.mk(Type.type, typeArgValue),
            ),
          );
          return Dict({
            dataTypeID: dataTypeValue,
            printID: eval(
              ctx,
              FnExpr.dart(
                argID: printArgID,
                argName: 'data',
                argType: Literal.mk(Type.type, dataTypeValue),
                returnType: Literal.mk(Type.type, text),
                body: (ctx, data) => print(ctx, dataTypeValue, data),
              ),
            ),
          });
        },
      );

  // static final listImpl = mkImpl(
  //   dataType: List.type,
  //   print: Fn.dart(
  //     argName: 'data',
  //     argType: Literal.mk(Type.type, List.type),
  //     returnType: Literal.mk(Type.type, text),
  //     body: (ctx, list) {
  //       var tree = TypeDef.tree(typeDef);
  //       return '${TypeTree.name(tree)}(${recurse(tree, Any.getValue(any))})';
  //     },
  //   ),
  // );

  static final printFn = FnExpr.dart(
    argName: 'object',
    argType: Literal.mk(Type.type, Any.type),
    returnType: Literal.mk(Type.type, text),
    body: (ctx, arg) {
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
            Fn.type(argID: printArgID, argType: dataType, returnType: Literal.mk(Type.type, text)),
            impl[printID].unwrap!,
          ),
          Literal.mk(dataType, dataType == Any.type ? arg : Any.getValue(arg)),
        ),
      );
    },
  );

  static final module = Module.mk(name: 'Print', definitions: [
    ValueDef.mk(id: ID('printFn'), name: 'print', value: printFn),
    InterfaceDef.mkDef(interfaceDef),
    ImplDef.mkDef(mkParameterizedImpl(
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
                    if (k == List.typeID) {
                      return '${TypeTree.name(v)}: type';
                    }
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
      argType: Type.type,
      dataType: (typeArg) => List.typeExpr(typeArg),
      print: (ctx, listType, data) {
        final memberType = Type.memberEquals(listType, [List.typeID]);
        return '[${List.iterate(data).map((elem) => palPrint(ctx, memberType, elem)).join(", ")}]';
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
    ImplDef.mkDef(mkImpl(
      dataType: number,
      print: (_, number) => '$number',
    )),
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
  ]);
}

String palPrint(Ctx ctx, Object type, Object value) =>
    eval(ctx, FnApp.mk(Printable.printFn, Literal.mk(Any.type, Any.mk(type, value)))) as String;

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
