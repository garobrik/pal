import 'package:ctx/ctx.dart';
import 'package:flutter/foundation.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'vec.g.dart';

@immutable
@ReifiedLens(type: ReifiedKind.list)
class Vec<Value> extends Iterable<Value>
    with _VecMixin<Value>, ToStringCtx, DiagnosticableTreeMixin {
  @override
  @skip
  final List<Value> _values;

  Vec.from(Iterable<Value> values) : _values = List.of(values, growable: false);
  const Vec([this._values = const []]);

  @override
  @reify
  int get length => _values.length;

  Vec<Value> get tail => Vec(_values.sublist(1));

  @reify
  Value operator [](int i) => _values[i];
  Vec<Value> mut_array_op(int i, Value update) => Vec.from(this).._values[i] = update;

  Vec<Value> insert(int index, Value v) {
    assert(0 <= index && index <= length);
    return Vec.from([..._values.take(index), v, ..._values.skip(index)]);
  }

  Diff _insert_mutated(int index, Value v) => Diff(
        added: PathSet.from({
          Vec([length])
        }),
        changed: PathSet.from({
          for (final j in range(length, start: index)) Vec([j]),
          const Vec(['length'])
        }),
      );

  Vec<Value> add(Value v) => insert(length, v);

  Vec<Value> append(Vec<Value> other) => Vec.from([..._values, ...other]);

  Vec<Value> remove(int index) {
    assert(0 <= index && index < length);
    return Vec.from([..._values.take(index), ..._values.skip(index + 1)]);
  }

  @override
  Vec<T> map<T>(T Function(Value) f) => Vec.from(_values.map(f));

  Diff _remove_mutated(int index) => Diff(
        changed: PathSet.from({
          for (final j in range(length - 1, start: index)) Vec([j]),
          const Vec(['length'])
        }),
        removed: PathSet.from({
          Vec([length - 1])
        }),
      );

  Vec<Value> sublist(int start, [int? end]) => Vec.from(_values.sublist(start, end));

  @override
  Iterator<Value> get iterator => _values.iterator;

  @override
  bool operator ==(Object other) {
    if (other is! Vec<Value>) return false;
    return iterableEqual(other);
  }

  @override
  int get hashCode => Object.hashAll(this);

  @override
  void doStringCtx(StringBuffer buffer, int leading) {
    if (this.isEmpty) {
      buffer.write('[]');
      return;
    }
    if (this.length == 1 && this.first is! ToStringCtx) {
      buffer.write('[${this.first}]');
      return;
    }
    buffer.write('[');
    for (final elem in this) {
      buffer.write('\n');
      buffer.write(''.padLeft(leading + 2));
      if (elem is ToStringCtx) {
        elem.doStringCtx(buffer, leading + 2);
      } else {
        buffer.write('$elem');
      }
      buffer.write(',');
    }
    buffer.writeln();
    buffer.write(']'.padLeft(leading + 1));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    var count = 0;
    return [
      for (final value in this)
        if (value is Diagnosticable)
          value.toDiagnosticsNode(name: 'child ${count++}')
        else
          DiagnosticsProperty('child ${count++}', value),
    ];
  }
}

extension IterableExtension<V> on Iterable<V> {
  int? indexWhere(bool Function(V) predicate) {
    var index = 0;
    for (final value in this) {
      if (predicate(value)) return index;
      index++;
    }
    return null;
  }
}

extension VecInsertCursorExtension<Value> on Cursor<Vec<Value>> {
  void add(Value v) {
    insert(length.read(Ctx.empty), v);
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
  Iterable<Cursor<T>> values(Ctx ctx) sync* {
    final length = this.length.read(ctx);
    for (final index in range(length)) {
      yield this[index];
    }
  }

  Iterable<IndexedValue<Cursor<T>>> indexedValues(Ctx ctx) sync* {
    final length = this.length.read(ctx);
    for (final index in range(length)) {
      yield IndexedValue(index, this[index]);
    }
  }
}

extension VecGetForEach<T> on GetCursor<Vec<T>> {
  Iterable<GetCursor<T>> values(Ctx ctx) sync* {
    final length = this.length.read(ctx);
    for (final index in range(length)) {
      yield this[index];
    }
  }

  Iterable<IndexedValue<GetCursor<T>>> indexedValues(Ctx ctx) sync* {
    final length = this.length.read(ctx);
    for (final index in range(length)) {
      yield IndexedValue(index, this[index]);
    }
  }
}
