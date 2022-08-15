import 'package:test/test.dart';
import 'package:knose/src/pal/pal2.dart';

final sillyID = ID();
final sillyRecordDef =
    TypeDef.record('silly', {sillyID: TypeTree.mk('silly', Literal.mk(Type.type, number))});

final testCtx = coreCtx.withType(Type.id(TypeDef.asType(sillyRecordDef)), sillyRecordDef);

void main() {
  test('RecordAccess + Literal', () {
    final expr = RecordAccess.mk(
      target: Literal.mk(TypeDef.asType(sillyRecordDef), Dict({sillyID: 0})),
      accessed: sillyID,
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
        Fn.type(argType: TypeDef.asType(sillyRecordDef), returnType: number),
        (argID) => RecordAccess.mk(target: VarAccess.mk(argID), accessed: sillyID),
      ),
      Literal.mk(TypeDef.asType(sillyRecordDef), Dict({sillyID: 0})),
    );

    final type = typeCheck(testCtx, expr);
    expect(type, equals(Option.mk(Type.type, number)));

    final result = eval(testCtx, expr);
    expect(result, equals(0));
  });

  test('InterfaceAccess + ThisDef', () {
    final ifaceID = ID();
    final dataTypeID = ID();
    final valueID = ID();
    final interfaceDef = InterfaceDef.mk(
      TypeTree.record('iface', {
        dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
        valueID: TypeTree.mk('value', InterfaceAccess.mk(target: thisDef, member: dataTypeID)),
      }),
      id: ifaceID,
    );

    final implID = ID();
    final implDef = ImplDef.mk(
      id: implID,
      implemented: ifaceID,
      members: Dict({dataTypeID: number, valueID: 0}),
    );

    final thisCtx = coreCtx.withImpl(implID, implDef).withInterface(ifaceID, interfaceDef);

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
