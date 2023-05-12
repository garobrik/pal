import 'package:reified_lenses/reified_lenses.dart';

extension IterableEquality<V> on Iterable<V> {
  bool iterableEqual(Iterable<V> other) =>
      length == other.length && zip(this, other).every((pair) => pair.first == pair.second);
}

extension IterableIntersperse<V> on Iterable<V> {
  Iterable<V> intersperse(V separator) sync* {
    if (this.isNotEmpty) yield this.first;
    for (final value in this.skip(1)) {
      yield separator;
      yield value;
    }
  }
}
