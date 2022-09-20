import 'package:ctx/ctx.dart';
import 'package:test/test.dart';
import 'package:knose/src/pal2/lang.dart';

final sillyID = ID();
final sillyRecordDef =
    TypeDef.record('silly', {sillyID: TypeTree.mk('silly', Literal.mk(Type.type, number))});

final testCtx = Option.unwrap(Module.load(
  coreCtx,
  Module.mk(name: 'Silly', definitions: [TypeDef.mkDef(sillyRecordDef)]),
)) as Ctx;

void main() {
  test('TypeCheckFn', () {
    final varFn = Fn.from(
      argName: 'arg',
      argType: Expr.type,
      returnType: Option.type(Type.type),
      body: (arg) => arg,
    );

    final result = eval(testCtx, FnApp.mk(varFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(result, equals(Literal.mk(number, 0)));

    final implFn = Fn.from(
      argName: 'arg',
      argType: Expr.type,
      returnType: Option.type(Type.type),
      body: (arg) => RecordAccess.mk(target: arg, member: Expr.implID),
    );

    final result2 = eval(testCtx, FnApp.mk(implFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect((result2 as Dict)[Expr.dataTypeID].unwrap!, equals(TypeDef.asType(Literal.typeDef)));

    final ifaceFn = Fn.from(
      argName: 'arg',
      argType: Expr.type,
      returnType: Option.type(Type.type),
      body: (arg) => RecordAccess.mk(
        target: RecordAccess.mk(target: arg, member: Expr.implID),
        member: Expr.typeCheckID,
      ),
    );

    final result3 = eval(testCtx, FnApp.mk(ifaceFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(
      result3,
      equals(Expr.data((ImplDef.members(Literal.exprImplDef) as Dict)[Expr.typeCheckID].unwrap!)),
    );

    final dataFn = Fn.from(
      argName: 'arg',
      argType: Expr.type,
      returnType: Option.type(Type.type),
      body: (arg) => RecordAccess.mk(target: arg, member: Expr.dataID),
    );

    final result4 = eval(testCtx, FnApp.mk(dataFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(
      result4,
      equals(Dict({Literal.typeID: number, Literal.valueID: 0})),
    );

    final typeCheckFn = Fn.from(
      argName: 'arg',
      argType: Expr.type,
      returnType: Option.type(Type.type),
      body: (arg) => FnApp.mk(
        RecordAccess.mk(
          target: RecordAccess.mk(target: arg, member: Expr.implID),
          member: Expr.typeCheckID,
        ),
        RecordAccess.mk(target: arg, member: Expr.dataID),
      ),
    );

    final result5 =
        eval(testCtx, FnApp.mk(typeCheckFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(result5, equals(Option.mk(Type.type, number)));
  });

  test('RecordAccess + Literal', () {
    final expr = RecordAccess.mk(
      target: Literal.mk(TypeDef.asType(sillyRecordDef), Dict({sillyID: 0})),
      member: sillyID,
    );

    final type = typeCheck(testCtx, expr);
    expect(type, equals(Option.mk(Type.type, number)));

    final result = eval(testCtx, expr);
    expect(result, equals(0));
  });

  test('Construct', () {
    final expr = Construct.mk(
      TypeDef.asType(sillyRecordDef),
      Dict({sillyID: Literal.mk(number, 0)}),
    );

    final type = typeCheck(testCtx, expr);
    expect(type, equals(Option.mk(Type.type, TypeDef.asType(sillyRecordDef))));

    final result = eval(testCtx, expr);
    expect(result, equals(Dict({sillyID: 0})));
  });

  test('Fn + FnApp + VarAccess', () {
    final expr = FnApp.mk(
      Fn.from(
        argName: 'arg',
        argType: TypeDef.asType(sillyRecordDef),
        returnType: number,
        body: (arg) => RecordAccess.mk(target: arg, member: sillyID),
      ),
      Literal.mk(TypeDef.asType(sillyRecordDef), Dict({sillyID: 0})),
    );

    final type = typeCheck(testCtx, expr);
    expect(type, equals(Option.mk(Type.type, number)));

    final result = eval(testCtx, expr);
    expect(result, equals(0));
  });

  test('InterfaceAccess + self reference', () {
    final ifaceID = ID('testIface');
    final dataTypeID = ID('testDataType');
    final valueID = ID('testValue');
    final interfaceDef = InterfaceDef.mk(
      TypeTree.record('testIface', {
        dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
        valueID: TypeTree.mk('value', Var.mk(dataTypeID)),
      }),
      id: ifaceID,
    );

    final implID = ID('testImpl');
    final implDef = ImplDef.mk(
      id: implID,
      implemented: ifaceID,
      members: Dict({dataTypeID: Literal.mk(Type.type, number), valueID: Literal.mk(number, 0)}),
    );

    final impl = ImplDef.asImpl(coreCtx, interfaceDef, implDef);
    final interfaceCtx = Option.unwrap(Module.load(
      coreCtx,
      Module.mk(name: 'testIface', definitions: [InterfaceDef.mkDef(interfaceDef)]),
    )) as Ctx;
    final thisCtx = Option.unwrap(Module.load(
      interfaceCtx,
      Module.mk(name: 'testIface', definitions: [ImplDef.mkDef(implDef)]),
    )) as Ctx;

    final expr = RecordAccess.mk(
      target: Literal.mk(
        InterfaceDef.implType(interfaceDef, [
          MemberHas.mkEquals([dataTypeID], Type.type, number)
        ]),
        impl,
      ),
      member: valueID,
    );
    final type = typeCheck(thisCtx, expr);
    expect(type, equals(Option.mk(Type.type, number)));

    final result = eval(thisCtx, expr);
    expect(result, equals(0));
  });

  test('load core module', () {
    expect(Option.isPresent(Module.load(Ctx.empty, coreModule)), isTrue);
  });

  test('dispatch', () {
    final maybeLiteral = dispatch(
      coreCtx,
      Expr.interfaceID,
      Type.mk(InterfaceDef.innerTypeDefID(Expr.interfaceID), properties: [
        MemberHas.mkEquals([Expr.dataTypeID], Type.type, Literal.type),
      ]),
    );

    expect(Option.isPresent(maybeLiteral), isTrue);
    expect(Option.unwrap(maybeLiteral), equals(Literal.exprImpl));
  });
}
