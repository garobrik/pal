import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'vec.g.dart';

@immutable
@reified_lens
class Vec<Value> extends Iterable<Value> {
  final List<Value> _values;

  Vec.from(Iterable<Value> values) : _values = List.of(values, growable: false);
  const Vec.of(List<Value> values) : _values = values;
  const Vec.empty() : _values = const [];

  Value operator [](int i) => _values[i];
  Vec<Value> mut_array_op(int i, Value v) {
    final newVec = Vec.from(this);
    newVec._values[i] = v;
    return newVec;
  }

  @skip_lens
  Vec<Value> insert(int index, Value v) {
    assert(0 <= index && index <= length);
    final copied = List.of(_values);
    copied.insert(index, v);
    return Vec.of(copied);
  }

  @skip_lens
  TrieSet<Object> _insert_mutations(int index, Value v) => TrieSet.from({
        for (final j in range(start: index, end: length)) [j],
        ['length']
      });

  @skip_lens
  Vec<Value> remove(int index) {
    assert(0 <= index && index < length);
    final copied = List.of(_values);
    copied.removeAt(index);
    return Vec.of(copied);
  }

  TrieSet<Object> _remove_mutations(int index) => TrieSet.from({
        for (final j in range(start: index, end: length - 1)) [j],
        ['length']
      });

  @override
  int get length => _values.length;

  @override
  @skip_lens
  Iterator<Value> get iterator => _values.iterator;
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

Iterable<int> range({int start = 0, required int end, int step = 1}) =>
    Iterable.generate((end - start) ~/ step, (i) => start + step * i);

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
