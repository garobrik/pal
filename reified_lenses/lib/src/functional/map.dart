import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'map.g.dart';

@immutable
@ReifiedLens(type: ReifiedKind.map)
class Dict<Key extends Object, Value> with _DictMixin<Key, Value> {
  @override
  @skip
  final Map<Key, Value> _values;

  const Dict([this._values = const {}]);

  @reify
  int get length => _values.length;

  @reify
  Iterable<Key> get keys => _values.keys;

  Iterable<Value> get values => _values.values;

  @reify
  Optional<Value> operator [](Key key) => Optional.fromNullable(_values[key]);
  Dict<Key, Value> mut_array_op(Key key, Optional<Value> update) => update.cases(
        some: (update) => Dict(Map.of(_values)).._values[key] = update,
        none: () => Dict(Map.of(_values)).._values.remove(key),
      );

  Dict<Key, Value> put(Key key, Value value) => mut_array_op(key, Optional(value));

  Diff _mut_array_op_mutated(Key key, Optional<Value> update) {
    return update.cases(some: (update) {
      if (!_values.containsKey(key)) {
        return Diff(
          added: PathSet.from({
            [
              Vec<dynamic>(<dynamic>['[]', key])
            ]
          }),
          changed: PathSet.from({
            ['keys'],
            ['length'],
          }),
        );
      } else {
        return Diff(
          changed: PathSet.from({
            [
              Vec<dynamic>(<dynamic>['[]', key])
            ]
          }),
        );
      }
    }, none: () {
      if (!_values.containsKey(key)) {
        return const Diff();
      } else {
        return Diff(
          removed: PathSet.from({
            [
              Vec<dynamic>(<dynamic>['[]', key])
            ]
          }),
          changed: PathSet.from({
            ['keys'],
            ['length'],
          }),
        );
      }
    });
  }

  Dict<Key, Value> remove(Key key) {
    final newDict = Dict(Map.of(_values));
    newDict._values.remove(key);
    return newDict;
  }

  Diff _remove_mutated(Key key) {
    if (_values.containsKey(key)) {
      return Diff(
        removed: PathSet.from({
          [key]
        }),
        changed: PathSet.from({
          ['keys'],
          ['length']
        }),
      );
    } else {
      return const Diff();
    }
  }

  @override
  Iterable<MapEntry<Key, Value>> get entries => _values.entries;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('{');
    for (final entry in entries) {
      buffer.write('${entry.key}: ${entry.value}, ');
    }
    buffer.write('}');
    return buffer.toString();
  }

  String toStringCtx() {
    final buffer = StringBuffer();
    _toStringCtx(buffer, 0);
    return buffer.toString();
  }

  void _toStringCtx(StringBuffer buffer, int leading) {
    buffer.write('{');
    for (final entry in entries) {
      buffer.write('\n');
      buffer.write(''.padLeft(leading + 2));
      buffer.write('${entry.key}: ');
      if (entry.value is Dict<Object, Object>) {
        (entry.value as Dict<Object, Object>)._toStringCtx(buffer, leading + 2);
      } else {
        buffer.write('${entry.value}');
      }
      buffer.write(',');
    }
    buffer.write('\n');
    buffer.write('}'.padLeft(leading + 1));
  }

  @override
  bool operator ==(Object other) {
    if (other is! Dict<Key, Value>) return false;
    if (other.length != length) return false;
    for (final entry in this.entries) {
      if (other[entry.key] != Optional(entry.value)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
        for (final entry in entries) ...[entry.key, entry.value]
      ]);

  Dict<Key, Value> merge(Dict<Key, Value> other, {Value Function(Value, Value)? onConflict}) {
    final newMap = <Key, Value>{};
    for (final entry in this.entries) {
      final otherValue = other[entry.key];
      newMap[entry.key] = otherValue.cases(
        some: (otherValue) =>
            onConflict == null ? entry.value : onConflict(entry.value, otherValue),
        none: () => entry.value,
      );
    }
    newMap.addAll({
      for (final entry in other.entries)
        if (this[entry.key].isEmpty) entry.key: entry.value
    });

    return Dict(newMap);
  }

  Dict<Key, Value2> mapValues<Value2>(Value2 Function(Key k, Value v) fn) =>
      Dict(_values.map((key, value) => MapEntry(key, fn(key, value))));

  bool containsKey(Key key) => _values.containsKey(key);
}
