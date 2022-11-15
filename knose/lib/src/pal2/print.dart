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

  static const printFnID =
      ID.constant(id: '0043f7c5-fcc8-466e-b575-25eb6a1a4fd1', hashCode: 25799240, label: 'print');
  static const moduleID =
      ID.constant(id: 'd522e29d-bff9-45d8-b017-0021330d2474', hashCode: 236908208, label: 'print');

  @DartFn('0a433255-e890-48a8-b649-bdc5c8683101')
  static Object _printFn(Ctx ctx, Object arg) {
    final impl = Option.unwrap(
      dispatch(
        ctx,
        InterfaceDef.id(interfaceDef),
        InterfaceDef.implType(interfaceDef, {dataTypeID: Any.getType(arg)}),
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
    final props = Type.properties(type).entries.map((prop) {
      final typeTree = TypeTree.find(tree, prop.key as ID);
      String name = prop.key.toString();
      String value = prop.value.toString();
      if (typeTree != null) {
        name = TypeTree.name(typeTree);
        final leaf = TypeTree.treeCases(
          typeTree,
          record: (_) => throw Error(),
          union: (_) => throw Error(),
          leaf: (_) => _,
        );
        if (Expr.dataType(leaf) == Literal.type) {
          value = palPrint(ctx, Literal.getValue(Expr.data(leaf)), prop.value);
        }
      }
      return Pair.mk(name, value);
    });
    final suffix = props.isEmpty
        ? ''
        : props.length == 1
            ? '<${Pair.second(props.first)}>'
            : '<${props.map((p) => "${Pair.first(p)}: ${Pair.second(p)}").join(", ")}>';

    return '$name$suffix';
  }

  @DartFn('2d7f0fe7-deaf-45e0-871a-375d5843d904')
  static Object _numberFn(Ctx _, Object number) => '$number';
  @DartFn('969a93c8-3470-4908-9a98-d8dd9881a274')
  static Object _textFn(Ctx _, Object text) => '"$text"';
  @DartFn('8917399b-78d9-4d2d-9e8e-3c420aef3b54')
  static Object _exprFn(Ctx ctx, Object expr) =>
      palPrint(ctx, Expr.dataType(expr), Expr.data(expr));
  @DartFn('b5418a3c-c0ce-431c-bd6c-885a6aed3712')
  static Object _idFn(Ctx ctx, Object id) => '$id';
  @DartFn('57d1377c-16ea-4bce-8e91-e34742321815')
  static Object _varFn(Ctx ctx, Object varData) => Option.cases(
        ctx.getBinding(Var.id(varData)),
        some: (binding) => Binding.name(ctx, binding),
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
