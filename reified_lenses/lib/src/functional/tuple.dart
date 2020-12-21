import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'tuple.g.dart';

@immutable
@reified_lens
class Pair<A, B> {
  final A first;
  final B second;

  Pair(this.first, this.second);
}

Iterable<Pair<A, B>> zip<A, B>(Iterable<A> aIterable, Iterable<B> bIterable) {
  return _ZipIterable(aIterable, bIterable);
}

class _ZipIterable<A, B> extends Iterable<Pair<A, B>> {
  final Iterable<A> aIterable;
  final Iterable<B> bIterable;

  _ZipIterable(this.aIterable, this.bIterable);

  @override
  Iterator<Pair<A, B>> get iterator =>
      _ZipIterator(aIterable.iterator, bIterable.iterator);
}

class _ZipIterator<A, B> extends Iterator<Pair<A, B>> {
  final Iterator<A> aIterator;
  final Iterator<B> bIterator;

  _ZipIterator(this.aIterator, this.bIterator);

  @override
  Pair<A, B> get current => Pair(aIterator.current, bIterator.current);

  @override
  bool moveNext() => aIterator.moveNext() && bIterator.moveNext();
}
