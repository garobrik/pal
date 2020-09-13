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

  int get length => _values.length;

  @override
  @skip_lens
  Iterator<Value> get iterator => _values.iterator;
}

extension VecForEach<A extends GetCursor, B> on Zoom<A, Vec<B>> {
  void forEach(void Function(Zoom<A, B> b) f) {
    final length = this.get(() {}).length;
    for (int i = 0; i < length; i++) {
      f(this[i]);
    }
  }
}
