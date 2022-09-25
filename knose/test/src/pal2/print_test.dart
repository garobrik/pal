import 'package:ctx/ctx.dart';
import 'package:knose/src/pal2/lang.dart';
import 'package:knose/src/pal2/print.dart';
import 'package:test/test.dart';

void main() {
  test('print ...', () {
    final ctx = Option.unwrap(Module.load(coreCtx, Printable.module)) as Ctx;
    final basicExpr = FnApp.mk(
      Printable.printFn,
      Literal.mk(Any.type, Any.mk(Option.type(number), Option.mk(number, 5))),
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
}
