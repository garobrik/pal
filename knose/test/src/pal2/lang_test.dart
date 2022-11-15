import 'package:ctx/ctx.dart';
import 'package:knose/src/pal2/print.dart';
import 'package:test/test.dart';
import 'package:knose/src/pal2/lang.dart';

void main() async {
  final coreModule = await Module.loadFromFile('core');
  final printModule = await Module.loadFromFile('Print');
  late final coreCtx = Module.load(
    Ctx.empty.withFnMap(langFnMap).withFnMap(Printable.fnMap),
    [coreModule, printModule],
  );

  test('load core module', () {
    expect(coreCtx, isNotNull);
  });

  final sillyID = ID.mk();
  final sillyRecordDef = TypeDef.record(
    'silly',
    {sillyID: TypeTree.mk('silly', Type.lit(number))},
    id: ID.mk(),
  );

  late final testCtx = Module.load(
    coreCtx,
    [
      Module.mk(id: ID.mk(), name: 'Silly', definitions: [TypeDef.mkDef(sillyRecordDef)])
    ],
  );

  test('TypeCheckFn', () {
    final varFn = FnExpr.from(
      argID: ID.mk(),
      argName: 'arg',
      argType: Type.lit(Expr.type),
      returnType: (_) => Type.lit(Option.type(Type.type)),
      body: (arg) => arg,
    );

    final result = eval(testCtx, FnApp.mk(varFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(result, equals(Literal.mk(number, 0)));

    final implFn = FnExpr.from(
      argID: ID.mk(),
      argName: 'arg',
      argType: Type.lit(Expr.type),
      returnType: (_) => Type.lit(Option.type(Type.type)),
      body: (arg) => RecordAccess.mk(arg, Expr.implID),
    );

    final result2 = eval(testCtx, FnApp.mk(implFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect((result2 as Dict)[Expr.dataTypeID].unwrap!, equals(TypeDef.asType(Literal.typeDef)));

    final dataFn = FnExpr.from(
      argID: ID.mk(),
      argName: 'arg',
      argType: Type.lit(Expr.type),
      returnType: (_) => Type.lit(Option.type(Type.type)),
      body: (arg) => RecordAccess.mk(arg, Expr.dataID),
    );

    final result4 = eval(testCtx, FnApp.mk(dataFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(
      result4,
      equals(Dict({Literal.typeID: number, Literal.valueID: 0})),
    );

    final typeCheckFn = FnExpr.from(
      argID: ID.mk(),
      argName: 'arg',
      argType: Type.lit(Expr.type),
      returnType: (_) => Type.lit(Option.type(Type.type)),
      body: (arg) => FnApp.mk(
        RecordAccess.mk(RecordAccess.mk(arg, Expr.implID), Expr.typeCheckID),
        RecordAccess.mk(arg, Expr.dataID),
      ),
    );

    final result5 =
        eval(testCtx, FnApp.mk(typeCheckFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(Result.isOk(result5), isTrue);
    expect(assignable(testCtx, Type.lit(number), Result.unwrap(result5)), isTrue);
  });

  test('RecordAccess + Literal', () {
    final expr = RecordAccess.mk(
      Literal.mk(TypeDef.asType(sillyRecordDef), Dict({sillyID: 0})),
      sillyID,
    );

    final type = typeCheck(testCtx, expr);
    expect(type, equals(Result.mkOk(Type.lit(number))));

    final result = eval(testCtx, expr);
    expect(result, equals(0));
  });

  test('Construct', () {
    final expr = Construct.mk(
      TypeDef.asType(sillyRecordDef),
      Dict({sillyID: Literal.mk(number, 0)}),
    );

    final type = typeCheck(testCtx, expr);
    expect(type, equals(Result.mkOk(Type.lit(TypeDef.asType(sillyRecordDef)))));

    final result = eval(testCtx, expr);
    expect(result, equals(Dict({sillyID: 0})));
  });

  test('Fn + FnApp + VarAccess', () {
    final expr = FnApp.mk(
      FnExpr.from(
        argID: ID.mk(),
        argName: 'arg',
        argType: Type.lit(TypeDef.asType(sillyRecordDef)),
        returnType: (_) => Type.lit(number),
        body: (arg) => RecordAccess.mk(arg, sillyID),
      ),
      Literal.mk(TypeDef.asType(sillyRecordDef), Dict({sillyID: 0})),
    );

    final type = typeCheck(testCtx, expr);
    expect(type, equals(Result.mkOk(Type.lit(number))));

    final result = eval(testCtx, expr);
    expect(result, equals(0));
  });

  test('InterfaceAccess + self reference', () {
    final ifaceID = ID.mk();
    final dataTypeID = ID.mk();
    final valueID = ID.mk();
    final interfaceDef = InterfaceDef.mk(
      TypeTree.record('testIface', {
        dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
        valueID: TypeTree.mk('value', Var.mk(dataTypeID)),
      }),
      id: ifaceID,
    );

    final implID = ID.mk();
    final implDef = ImplDef.mk(
      id: implID,
      name: 'testImpl',
      implemented: ifaceID,
      definition: Dict({dataTypeID: Type.lit(number), valueID: Literal.mk(number, 0)}),
    );

    final impl = ImplDef.asImpl(coreCtx, interfaceDef, implDef);
    final thisCtx = Module.load(coreCtx, [
      Module.mk(
        id: ID.mk(),
        name: 'testIface',
        definitions: [InterfaceDef.mkDef(interfaceDef), ImplDef.mkDef(implDef)],
      ),
    ]);

    final expr = RecordAccess.mk(
      Literal.mk(
        InterfaceDef.implType(interfaceDef, {dataTypeID: number}),
        impl,
      ),
      valueID,
    );
    final type = typeCheck(thisCtx, expr);
    expect(type, equals(Result.mkOk(Type.lit(number))));

    final result = eval(thisCtx, expr);
    expect(result, equals(0));
  });

  test('parametric function!', () {
    final arg = Var.mk(ID.mk());
    final fn = FnExpr.pal(
      argID: Var.id(Expr.data(arg)),
      argName: 'someting!!',
      argType: Type.lit(Literal.type),
      returnType: RecordAccess.mk(arg, Literal.typeID),
      body: RecordAccess.mk(arg, Literal.valueID),
    );

    expect(
      typeCheck(
        coreCtx,
        fn,
      ),
      equals(Result.mkOk(
        reduce(
          coreCtx,
          Fn.typeExpr(
            argID: Var.id(Expr.data(arg)),
            argType: Type.lit(Literal.type),
            returnType: RecordAccess.mk(arg, Literal.typeID),
          ),
        ),
      )),
    );

    final fnApplied = FnApp.mk(fn, Literal.mk(Literal.type, Expr.data(Literal.mk(number, 0))));
    expect(typeCheck(coreCtx, fnApplied), equals(Result.mkOk(Type.lit(number))));
    expect(eval(coreCtx, fnApplied), equals(0));
  });

  test('dispatch', () {
    final maybeLiteral = dispatch(
      coreCtx,
      Expr.interfaceID,
      InterfaceDef.implType(Expr.interfaceDef, {Expr.dataTypeID: Literal.type}),
    );

    expect(Option.isPresent(maybeLiteral), isTrue);
    expect(Option.unwrap(maybeLiteral), equals(Literal.exprImpl));
  });

  test('basic serialize', () {
    final arg = Option.mk(Pair.mk('hi', 5));
    expect(deserialize(serialize(arg, '')), equals(arg));
  });

  test('serialize core module', () {
    expect(deserialize(serialize(coreModule, '')), equals(coreModule));
  });
}
