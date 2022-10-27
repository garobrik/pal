import 'dart:io';

import 'package:ctx/ctx.dart';
import 'package:test/test.dart';
import 'package:knose/src/pal2/lang.dart';

void main() async {
  final coreModule = File('pal/core.pal').readAsString().then((str) => deserialize(str) as Object);
  final maybeCoreCtx =
      coreModule.then((module) => Module.load(Ctx.empty.withFnMap(langFnMap), module));
  final coreCtx = maybeCoreCtx.then((maybeCtx) => Option.unwrap(maybeCtx) as Ctx);

  test('load core module', () {
    expect(maybeCoreCtx.then(Option.isPresent), completion(isTrue));
  });

  final sillyID = ID.mk();
  final sillyRecordDef = TypeDef.record(
    'silly',
    {sillyID: TypeTree.mk('silly', Type.lit(number))},
    id: ID.mk(),
  );

  final testCtx = coreCtx.then(
    (coreCtx) => Option.unwrap(Module.load(
      coreCtx,
      Module.mk(id: ID.mk(), name: 'Silly', definitions: [TypeDef.mkDef(sillyRecordDef)]),
    )) as Ctx,
  );

  test('TypeCheckFn', () async {
    final varFn = FnExpr.from(
      argID: ID.mk(),
      argName: 'arg',
      argType: Type.lit(Expr.type),
      returnType: (_) => Type.lit(Option.type(Type.type)),
      body: (arg) => arg,
    );

    final result =
        eval(await testCtx, FnApp.mk(varFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(result, equals(Literal.mk(number, 0)));

    final implFn = FnExpr.from(
      argID: ID.mk(),
      argName: 'arg',
      argType: Type.lit(Expr.type),
      returnType: (_) => Type.lit(Option.type(Type.type)),
      body: (arg) => RecordAccess.mk(arg, Expr.implID),
    );

    final result2 =
        eval(await testCtx, FnApp.mk(implFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect((result2 as Dict)[Expr.dataTypeID].unwrap!, equals(TypeDef.asType(Literal.typeDef)));

    final dataFn = FnExpr.from(
      argID: ID.mk(),
      argName: 'arg',
      argType: Type.lit(Expr.type),
      returnType: (_) => Type.lit(Option.type(Type.type)),
      body: (arg) => RecordAccess.mk(arg, Expr.dataID),
    );

    final result4 =
        eval(await testCtx, FnApp.mk(dataFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
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
        eval(await testCtx, FnApp.mk(typeCheckFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(Result.isOk(result5), isTrue);
    expect(assignable(await testCtx, Type.lit(number), Result.unwrap(result5)), isTrue);
  });

  test('RecordAccess + Literal', () async {
    final expr = RecordAccess.mk(
      Literal.mk(TypeDef.asType(sillyRecordDef), Dict({sillyID: 0})),
      sillyID,
    );

    final type = typeCheck(await testCtx, expr);
    expect(type, equals(Result.mkOk(Type.lit(number))));

    final result = eval(await testCtx, expr);
    expect(result, equals(0));
  });

  test('Construct', () async {
    final expr = Construct.mk(
      TypeDef.asType(sillyRecordDef),
      Dict({sillyID: Literal.mk(number, 0)}),
    );

    final type = typeCheck(await testCtx, expr);
    expect(type, equals(Result.mkOk(Type.lit(TypeDef.asType(sillyRecordDef)))));

    final result = eval(await testCtx, expr);
    expect(result, equals(Dict({sillyID: 0})));
  });

  test('Fn + FnApp + VarAccess', () async {
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

    final type = typeCheck(await testCtx, expr);
    expect(type, equals(Result.mkOk(Type.lit(number))));

    final result = eval(await testCtx, expr);
    expect(result, equals(0));
  });

  test('InterfaceAccess + self reference', () async {
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
      implemented: ifaceID,
      definition: Dict({dataTypeID: Type.lit(number), valueID: Literal.mk(number, 0)}),
    );

    final impl = ImplDef.asImpl(await coreCtx, interfaceDef, implDef);
    final thisCtx = Option.unwrap(Module.load(
      await coreCtx,
      Module.mk(
        id: ID.mk(),
        name: 'testIface',
        definitions: [InterfaceDef.mkDef(interfaceDef), ImplDef.mkDef(implDef)],
      ),
    )) as Ctx;

    final expr = RecordAccess.mk(
      Literal.mk(
        InterfaceDef.implType(interfaceDef, [
          MemberHas.mkEquals([dataTypeID], Type.type, number)
        ]),
        impl,
      ),
      valueID,
    );
    final type = typeCheck(thisCtx, expr);
    expect(type, equals(Result.mkOk(Type.lit(number))));

    final result = eval(thisCtx, expr);
    expect(result, equals(0));
  });

  test('parametric function!', () async {
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
        await coreCtx,
        fn,
      ),
      equals(Result.mkOk(
        reduce(
          await coreCtx,
          Fn.typeExpr(
            argID: Var.id(Expr.data(arg)),
            argType: Type.lit(Literal.type),
            returnType: RecordAccess.mk(arg, Literal.typeID),
          ),
        ),
      )),
    );

    final fnApplied = FnApp.mk(fn, Literal.mk(Literal.type, Expr.data(Literal.mk(number, 0))));
    expect(typeCheck(await coreCtx, fnApplied), equals(Result.mkOk(Type.lit(number))));
    expect(eval(await coreCtx, fnApplied), equals(0));
  });

  test('dispatch', () async {
    final maybeLiteral = dispatch(
      await coreCtx,
      Expr.interfaceID,
      InterfaceDef.implType(Expr.interfaceDef, [
        MemberHas.mkEquals([Expr.dataTypeID], Type.type, Literal.type),
      ]),
    );

    expect(Option.isPresent(maybeLiteral), isTrue);
    expect(Option.unwrap(maybeLiteral), equals(Literal.exprImpl));
  });

  test('basic serialize', () {
    final arg = Option.mk(Pair.mk('hi', 5));
    expect(deserialize(serialize(arg, '')), equals(arg));
  });

  test('serialize core module', () async {
    expect(deserialize(serialize(await coreModule, '')), equals(await coreModule));
  });
}
