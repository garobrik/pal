import 'package:functional/src/optional.dart';
import 'package:test/test.dart';

void main() {
  test('Optional()', () {
    expect(Optional(0).value, 0);
    expect(() => Optional(null), throwsA(isA<AssertionError>()));
  });

  test('Optional.nullable()', () {
    expect(Optional.nullable(0).value, 0);
    expect(Optional.nullable(null).isEmpty, true);
  });

  test('Optional.empty', () {
    expect(Optional<int>.empty().isEmpty, true);
    final Optional<String> opt = Optional.empty();
    expect(opt.isEmpty, true);
  });

  test('Optional.or', () {
    expect(Optional<int>.empty().or(0), 0);
    expect(Optional(1).or(0), 1);
  });

  test('Optional.map', () {
    expect(Optional(0).map((i) => i + 1).value, 1);
    final Optional<String> opt = Optional.empty();
    expect(opt.map((s) => s.toUpperCase()).isEmpty, true);
  });

  test('Optional is Iterable', () {
    expect(Optional<int>.empty().length, 0);
    expect(Optional(0).length, 1);
    expect(Optional(0).where((i) => i != 0).length, 0);
  });
}