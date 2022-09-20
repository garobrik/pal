import 'package:ctx/ctx.dart';
import 'package:knose/src/pal2/lang.dart';

abstract class Printable {
  static final dataTypeID = ID('dataType');
  static final printID = ID('print');
  static final interfaceDef = InterfaceDef.record('Printable', {
    dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    printID: TypeTree.mk(
      'print',
      Fn.typeExpr(
        argType: Var.mk(dataTypeID),
        returnType: Literal.mk(Type.type, text),
      ),
    ),
  });

  static Object mkImpl({required Object dataType, required Object print}) => ImplDef.mk(
        implemented: InterfaceDef.id(interfaceDef),
        members: Dict({dataTypeID: Literal.mk(Type.type, dataType), printID: print}),
      );

  static final anyImpl = mkImpl(
    dataType: Any.type,
    print: Fn.dart(
      argName: 'data',
      type: Fn.type(argType: Any.type, returnType: text),
      body: (ctx, any) {
        final typeDef = ctx.getType(Type.id(Any.getType(any)));

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
            leaf: (leaf) {
              final leafType = eval(ctx, leaf);
              return eval(ctx, FnApp.mk(printFn, Literal.mk(Any.type, Any.mk(leafType, dataTree))))
                  as String;
            },
          );
        }

        var tree = TypeDef.tree(typeDef);
        final resultString = recurse(
          TypeTree.dataBindings(typeDef, Any.getValue(any)).fold(
            ctx,
            (ctx, binding) => ctx.withBinding(binding),
          ),
          tree,
          Any.getValue(any),
        );
        return '${TypeTree.name(tree)}($resultString)';
      },
    ),
  );

  static final typeImpl = mkImpl(
    dataType: Type.type,
    print: Fn.dart(
      argName: 'type',
      type: Fn.type(argType: Type.type, returnType: text),
      body: (ctx, type) {
        final tree = TypeDef.tree(ctx.getType(Type.id(type)));
        final name = TypeTree.name(tree);
        final props = List.iterate(Type.properties(type))
            .map((prop) => eval(ctx, FnApp.mk(printFn, Any.mk(TypeProperty.type, prop))));
        final suffix = props.isEmpty ? '' : '<${props.join(", ")}>';
        return '$name$suffix';
      },
    ),
  );

  static final numberImpl = mkImpl(
    dataType: number,
    print: Fn.dart(
      argName: 'number',
      type: Fn.type(argType: number, returnType: text),
      body: (ctx, number) {
        return '$number';
      },
    ),
  );

  // static final listImpl = mkImpl(
  //   dataType: List.type,
  //   print: Fn.dart(
  //     argName: 'data',
  //     type: Fn.type(argType: List.type, returnType: text),
  //     body: (ctx, list) {
  //       var tree = TypeDef.tree(typeDef);
  //       return '${TypeTree.name(tree)}(${recurse(tree, Any.getValue(any))})';
  //     },
  //   ),
  // );

  static final printFn = Fn.dart(
    argName: 'object',
    type: Fn.type(argType: Any.type, returnType: text),
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
            Fn.type(argType: dataType, returnType: text),
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
    ImplDef.mkDef(anyImpl),
    ImplDef.mkDef(typeImpl),
    ImplDef.mkDef(numberImpl),
  ]);
}

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
  - data access

  - fn
  - fn app
*/
