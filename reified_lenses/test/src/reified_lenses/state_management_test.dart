import 'package:ctx/ctx.dart';
import 'package:reified_lenses/reified_lenses.dart';
import 'package:test/test.dart';

part 'state_management_test.g.dart';

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
    test('Very complex', () {
      final cursor = Cursor<Dict<String, PalValue>>(Dict({}));
      bool listenedBool = false;
      final boolCursor = cursor['test'].asPalOption(Optional).value.cast<Optional<PalValue>>();
      boolCursor.listen((_, __, ___) => listenedBool = true);
      boolCursor.set(Optional(PalValue(bool, true)));
      expect(cursor.read(Ctx.empty)['test'].unwrap!.value, true,
          reason: 'Dict should have updated!');
      expect(listenedBool, true, reason: 'Bool cursor should have notified listeners!');
    });
  });
}

@reify
class PalValue with _PalValueMixin {
  @override
  final Object type;
  @override
  final Object value;

  PalValue(this.type, this.value);
}

extension OptionalPalValueCursorExtension on Cursor<Optional<PalValue>> {
  Cursor<PalValue> asPalOption(Object type) => partial(
        to: (opt) => PalValue(type, opt),
        from: (diff) => DiffResult(diff.value.value as Optional<PalValue>, diff.diff),
      );
}
