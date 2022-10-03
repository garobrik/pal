import 'package:ctx/ctx.dart';
import 'package:knose/src/pal2/lang.dart';
import 'package:knose/src/pal2/print.dart';
import 'package:test/test.dart';

void main() {
  late final ctx = Option.unwrap(Module.load(coreCtx, Printable.module)) as Ctx;

  test('print option', () {
    final basicExpr = FnApp.mk(
      Var.mk(Printable.printFnID),
      Literal.mk(Any.type, Any.mk(Option.type(number), Option.mk(5))),
    );

    final type = typeCheck(ctx, basicExpr);
    expect(Option.isPresent(type), isTrue);
    expect(Option.unwrap(type), equals(Literal.mk(Type.type, text)));
    expect(
      eval(ctx, basicExpr),
      equals(
        'Option(dataType: Number, value: some(5))',
      ),
    );
  });

  test('print type', () {
    final compoundTypeExpr = FnApp.mk(
      Var.mk(Printable.printFnID),
      Literal.mk(Any.type, Any.mk(Type.type, List.type(Option.type(text)))),
    );

    final type = typeCheck(ctx, compoundTypeExpr);
    expect(Option.isPresent(type), isTrue);
    expect(Option.unwrap(type), equals(Literal.mk(Type.type, text)));
    expect(
      eval(ctx, compoundTypeExpr),
      equals(
        'List<type = Option<dataType = Text>>',
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
}
