import 'package:ctx/ctx.dart';
import 'package:test/test.dart';

void main() {
  test('basic', () {
    var ctx = Ctx.empty;
    expect(ctx.get<NumberElement>()?.number, equals(null));
    expect(ctx.get<StringElement>()?.string, equals(null));

    ctx = ctx.withElement(NumberElement(1));
    expect(ctx.get<NumberElement>()?.number, equals(1));
    expect(ctx.get<StringElement>()?.string, equals(null));

    ctx = ctx.withElement(StringElement('test'));
    expect(ctx.get<NumberElement>()?.number, equals(1));
    expect(ctx.get<StringElement>()?.string, equals('test'));

    ctx = ctx.withElement(NumberElement(2));
    expect(ctx.get<NumberElement>()?.number, equals(2));
    expect(ctx.get<StringElement>()?.string, equals('test'));

    ctx = ctx.removeElement<StringElement>();
    expect(ctx.get<NumberElement>()?.number, equals(2));
    expect(ctx.get<StringElement>()?.string, equals(null));
  });
}

class NumberElement extends CtxElement {
  final int number;

  NumberElement(this.number);
}

class StringElement extends CtxElement {
  final String string;

  StringElement(this.string);
}
