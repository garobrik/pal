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

  static ReifiedTransformF<Vec<Value>> insert<Value>(int i, Value v) {
    return (vec) {
      final copied = List.of(vec._values);
      copied.insert(i, v);
      return MutResult(
        Vec.of(copied),
        Path.singleton(i),
      );
    };
  }

  @override
  int get length => _values.length;

  @override
  @skip_lens
  Iterator<Value> get iterator => _values.iterator;
}

extension VecForEach<T> on Cursor<Vec<T>> {
  void forEach(void Function(Cursor<T> b) f) {
    final length = this.length.get();
    for (int i = 0; i < length; i++) {
      f(this[i]);
    }
  }
}

extension VecGetForEach<T> on GetCursor<Vec<T>> {
  void forEach(void Function(GetCursor<T> b) f) {
    final length = this.length.get();
    for (int i = 0; i < length; i++) {
      f(this[i]);
    }
  }
}
