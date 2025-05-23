import 'package:ctx/ctx.dart';
import 'package:knose/src/pal2/lang.dart';
import 'package:knose/src/pal2/print.dart';
import 'package:test/test.dart';

void main() async {
  final coreModule = await Module.loadFromFile('core');
  final printModule = await Module.loadFromFile('Print');
  late final ctx = Module.load(
    Ctx.empty.withFnMap(langFnMap).withFnMap(Printable.fnMap),
    [coreModule, printModule],
  );

  test('print option', () {
    final basicExpr = FnApp.mk(
      Var.mk(Printable.printFnID),
      Literal.mk(Any.type, Any.mk(Option.type(number), Option.mk(5))),
    );

    final type = typeCheck(ctx, basicExpr);
    expect(Result.isOk(type), isTrue);
    expect(Result.unwrap(type), equals(Type.lit(text)));
    expect(
      eval(ctx, basicExpr),
      equals(
        'Option(value: some(5), dataType: Number)',
      ),
    );
  });

  test('print type', () {
    final compoundTypeExpr = FnApp.mk(
      Var.mk(Printable.printFnID),
      Literal.mk(Any.type, Any.mk(Type.type, List.type(Option.type(text)))),
    );

    final type = typeCheck(ctx, compoundTypeExpr);
    expect(Result.isOk(type), isTrue);
    expect(Result.unwrap(type), equals(Type.lit(text)));
    expect(
      eval(ctx, compoundTypeExpr),
      equals(
        'List<Option<Text>>',
      ),
    );
  });

  test('print var', () {
    expect(
      palPrint(ctx, Expr.type, Var.mk(Printable.printFnID)),
      equals(
        'print',
      ),
    );
  });

  test('print any', () {
    expect(
      palPrint(
        ctx,
        Any.type,
        Any.mk(number, 5),
      ),
      equals(
        'Any(type: Number, value: 5)',
      ),
    );
  });

  test('print map', () {
    expect(
      palPrint(
        ctx,
        Map.type(text, number),
        Map.mk({'zero': 0, 'one': 1}),
      ),
      equals(
        '{"zero": 0, "one": 1}',
      ),
    );
  });

  test('print type tree', () {
    expect(
      palPrint(
        ctx,
        TypeTree.type,
        InterfaceDef.tree(ModuleDef.interfaceDef),
      ),
      equals(
        'TypeTree(name: "ModuleDef", tree: record({ID(dataType): TypeTree(name: "dataType", tree: leaf(Type)), ID(bindings): TypeTree(name: "bindings", tree: leaf(Type.mk(id: ID(Fn), path: [], properties: MkMap(valueType: Unit, entries: [Pair(second: ID(bindingsArg), First: Expr, first: ID(argID), Second: Expr), Pair(second: ModuleDef.dataType, First: Expr, first: ID(argType), Second: Expr), Pair(second: List<Union<[ModuleDef, Binding]>>, First: Expr, first: ID(returnType), Second: Expr)], keyType: ID))))}))',
      ),
    );
  });
}
