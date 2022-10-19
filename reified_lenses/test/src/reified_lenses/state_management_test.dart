import 'package:ctx/ctx.dart';
import 'package:reified_lenses/reified_lenses.dart';
import 'package:test/test.dart';

void main() {
  group('Cursor casts:', () {
    test('Basic', () {
      final cursor = Cursor<Object>(false);
      bool listened = false;
      cursor.cast<bool>().listen((_, __, ___) => listened = true);
      cursor.cast<bool>().set(true);
      expect(listened, true);
    });
    test('Complex', () {
      final cursor = Cursor<Dict<String, Object>>(Dict({}));
      bool listened = false;
      cursor['test'].orElse(false).cast<bool>().listen((_, __, ___) => listened = true);
      cursor['test'].orElse(false).cast<bool>().set(true);
      expect(listened, true);
      expect(cursor.read(Ctx.empty)['test'].unwrap!, true);
    });
  });
}
