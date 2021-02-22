import 'package:reified_lenses/reified_lenses.dart';

extension IterableEquality<V> on Iterable<V> {
  bool iterableEqual(Iterable<V> other) =>
      length == other.length &&
      zip(this, other).any((pair) => pair.first == pair.second);
}

int hash(Iterable iterable) {
  int result = 1;
  for (final value in iterable) result = 31 * result + value.hashCode;
  return result;
}
