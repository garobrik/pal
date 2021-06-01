import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'vec.g.dart';

@immutable
@ReifiedLens(type: ReifiedKind.List)
class Vec<Value> extends Iterable<Value> with _VecMixin<Value> {
  @skip
  final List<Value> _values;

  Vec.from(Iterable<Value> values) : _values = List.of(values, growable: false);
  const Vec([this._values = const []]);

  @override
  @reify
  int get length => _values.length;

  @reify
  Value operator [](int i) => _values[i];
  Vec<Value> mut_array_op(int i, Value update) => Vec.from(this).._values[i] = update;

  Vec<Value> insert(int index, Value v) {
    assert(0 <= index && index <= length);
    return Vec.from([..._values.take(index), v, ..._values.skip(index)]);
  }

  Diff _insert_mutated(int index, Value v) => Diff(
        added: PathSet.from({
          [length]
        }),
        changed: PathSet.from({
          for (final j in range(length, start: index)) [j],
          ['length']
        }),
      );

  Vec<Value> remove(int index) {
    assert(0 <= index && index < length);
    return Vec.from([..._values.take(index), ..._values.skip(index + 1)]);
  }

  Diff _remove_mutated(int index) => Diff(
        changed: PathSet.from({
          for (final j in range(length - 1, start: index)) [j],
          const ['length']
        }),
        removed: PathSet.from({
          [length - 1]
        }),
      );

  @override
  Iterator<Value> get iterator => _values.iterator;

  @override
  bool operator ==(Object other) {
    if (other is! Vec<Value>) return false;
    return iterableEqual(other);
  }

  @override
  int get hashCode => hash(this);
}

extension VecInsertCursorExtension<Value> on Cursor<Vec<Value>> {
  void add(Value v) {
    insert(length.read(noopReader), v);
  }
}

Iterable<int> range(int end, {int start = 0, int step = 1}) sync* {
  for (var i = start; i < end; i += step) {
    yield i;
  }
}

class IndexedValue<T> {
  final int index;
  final T value;

  IndexedValue(this.index, this.value);
}

extension VecForEach<T> on Cursor<Vec<T>> {
  Iterable<Cursor<T>> values(Reader reader) sync* {
    final length = this.length.read(reader);
    for (final index in range(length)) {
      yield this[index];
    }
  }

  Iterable<IndexedValue<Cursor<T>>> indexedValues(Reader reader) sync* {
    final length = this.length.read(reader);
    for (final index in range(length)) {
      yield IndexedValue(index, this[index]);
    }
  }
}

extension VecGetForEach<T> on GetCursor<Vec<T>> {
  Iterable<GetCursor<T>> values(Reader reader) sync* {
    final length = this.length.read(reader);
    for (final index in range(length)) {
      yield this[index];
    }
  }

  Iterable<IndexedValue<GetCursor<T>>> indexedValues(Reader reader) sync* {
    final length = this.length.read(reader);
    for (final index in range(length)) {
      yield IndexedValue(index, this[index]);
    }
  }
}
