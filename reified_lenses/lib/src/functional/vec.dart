import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'vec.g.dart';

@immutable
@reify
class Vec<Value> extends Iterable<Value> {
  @skip
  final List<Value> _values;

  Vec.from(Iterable<Value> values) : _values = List.of(values, growable: false);
  const Vec(this._values);
  const Vec.empty() : _values = const [];

  @override
  @reify
  int get length => _values.length;

  @reify
  Value operator [](int i) => _values[i];
  Vec<Value> mut_array_op(int i, Value Function(Value) update) {
    final newVec = Vec.from(this);
    newVec._values[i] = update(newVec._values[i]);
    return newVec;
  }

  Vec<Value> insert(int index, Value v) {
    assert(0 <= index && index <= length);
    return Vec.from(_values.take(index).followedBy([v]).followedBy(_values.skip(index)));
  }

  TrieSet<Object> _insert_mutations(int index, Value v) => TrieSet.from({
        for (final j in range(start: index, end: length)) [j],
        const ['length']
      });

  Vec<Value> remove(int index) {
    assert(0 <= index && index < length);
    return Vec.from(_values.take(index).followedBy(_values.skip(index + 1)));
  }

  TrieSet<Object> _remove_mutations(int index) => TrieSet.from({
        for (final j in range(start: index, end: length - 1)) [j],
        const ['length']
      });

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
  void insert(int i, Value v) {
    mutResult(
      (vec) => MutResult(
        vec.insert(i, v),
        const [],
        vec._insert_mutations(i, v),
      ),
    );
  }

  void remove(int i) {
    mutResult(
      (vec) => MutResult(
        vec.remove(i),
        const [],
        vec._remove_mutations(i),
      ),
    );
  }

  void add(Value v) {
    insert(length.get, v);
  }
}

Iterable<int> range({int start = 0, required int end, int step = 1}) sync* {
  for (var i = start; i < end; i += step) {
    yield i;
  }
}

extension VecForEach<T> on Cursor<Vec<T>> {
  void forEach(void Function(Cursor<T> b) f) {
    final length = this.length.get;
    for (int i = 0; i < length; i++) {
      f(this[i]);
    }
  }
}

extension VecGetForEach<T> on GetCursor<Vec<T>> {
  void forEach(void Function(GetCursor<T> b) f) {
    final length = this.length.get;
    for (int i = 0; i < length; i++) {
      f(this[i]);
    }
  }
}
