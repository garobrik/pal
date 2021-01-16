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
  Vec<Value> insert(int i, Value v) {
    final copied = List.of(_values);
    copied.insert(i, v);
    return Vec.of(copied);
  }

  @skip_lens
  Set<Iterable<Object>> insert_mutations(int i, Value v) => Set.of(
        range(start: i, end: length + 1)
            .map<Iterable<Object>>((i) => [i])
            .followedBy([
          ['length']
        ]),
      );

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
        vec.insert_mutations(i, v),
      ),
    );
  }

  void add(Value v) {
    insert(length.get, v);
  }
}

Iterable<int> range({required int start, int end = 0, int step = 1}) =>
    Iterable.generate((start - end) ~/ step, (i) => end + step * i);

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
