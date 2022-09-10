import 'package:test/test.dart';
import 'package:knose/src/pal2/lang.dart';

final sillyID = ID();
final sillyRecordDef =
    TypeDef.record('silly', {sillyID: TypeTree.mk('silly', Literal.mk(Type.type, number))});

final testCtx = coreCtx.withType(sillyRecordDef);

void main() {
  test('TypeCheckFn', () {
    final varFn = Fn.from(
      argName: 'arg',
      type: Fn.type(argType: Expr.type, returnType: Option.type(Type.type)),
      body: (arg) => arg,
    );

    final result = eval(testCtx, FnApp.mk(varFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(result, equals(Literal.mk(number, 0)));

    final implFn = Fn.from(
      argName: 'arg',
      type: Fn.type(argType: Expr.type, returnType: Option.type(Type.type)),
      body: (arg) => RecordAccess.mk(target: arg, member: Expr.implID),
    );

    final result2 = eval(testCtx, FnApp.mk(implFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(result2, equals(Literal.exprImpl));

    final ifaceFn = Fn.from(
      argName: 'arg',
      type: Fn.type(argType: Expr.type, returnType: Option.type(Type.type)),
      body: (arg) => InterfaceAccess.mk(
        target: RecordAccess.mk(target: arg, member: Expr.implID),
        member: Expr.evalTypeID,
      ),
    );

    final result3 = eval(testCtx, FnApp.mk(ifaceFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(
      result3,
      equals(Expr.data((ImplDef.members(Literal.exprImplDef) as Dict)[Expr.evalTypeID].unwrap!)),
    );

    final dataFn = Fn.from(
      argName: 'arg',
      type: Fn.type(argType: Expr.type, returnType: Option.type(Type.type)),
      body: (arg) => RecordAccess.mk(target: arg, member: Expr.dataID),
    );

    final result4 = eval(testCtx, FnApp.mk(dataFn, Literal.mk(Expr.type, Literal.mk(number, 0))));
    expect(
      result4,
      equals(Dict({Literal.typeID: number, Literal.valueID: 0})),
    );

    final typeCheckFn = Fn.from(
      argName: 'arg',
      type: Fn.type(argType: Expr.type, returnType: Option.type(Type.type)),
      body: (arg) => FnApp.mk(
        InterfaceAccess.mk(
          target: RecordAccess.mk(target: arg, member: Expr.implID),
          member: Expr.evalTypeID,
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
        type: Fn.type(argType: TypeDef.asType(sillyRecordDef), returnType: number),
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

    final implObj = ImplDef.asImplObj(coreCtx, interfaceDef, implDef);
    final thisCtx = coreCtx.withImpl(implID, implObj).withInterface(interfaceDef);

    final expr = InterfaceAccess.mk(
      target: Literal.mk(
        Impl.type(
          ifaceID,
          properties: Vec([
            MemberHas.mk(path: Vec([dataTypeID]), property: Equals.mk(Type.type, number))
          ]),
        ),
        Impl.mk(implID),
      ),
      member: valueID,
    );
    final type = typeCheck(thisCtx, expr);
    expect(type, equals(Option.mk(Type.type, number)));

    final result = eval(thisCtx, expr);
    expect(result, equals(0));
  });
}
