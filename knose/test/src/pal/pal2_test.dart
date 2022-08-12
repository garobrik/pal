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
}
