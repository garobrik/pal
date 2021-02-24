import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'tuple.g.dart';

@immutable
@reify
class Pair<A, B> {
  final A first;
  final B second;

  Pair(this.first, this.second);
}

Iterable<Pair<A, B>> zip<A, B>(
  Iterable<A> aIterable,
  Iterable<B> bIterable,
) sync* {
  final aIterator = aIterable.iterator;
  final bIterator = bIterable.iterator;
  while (aIterator.moveNext() && bIterator.moveNext())
    yield Pair(aIterator.current, bIterator.current);
}
