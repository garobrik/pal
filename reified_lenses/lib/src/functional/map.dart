import 'package:ctx/ctx.dart';
import 'package:flutter/foundation.dart';
import 'package:reified_lenses/reified_lenses.dart';

part 'map.g.dart';

@immutable
@ReifiedLens(type: ReifiedKind.map)
class Dict<Key extends Object, Value> with _DictMixin<Key, Value>, DiagnosticableTreeMixin {
  @override
  @skip
  final Map<Key, Value> _values;

  const Dict([this._values = const {}]);

  static GetCursor<Dict<Object, Object>> cursor(Map<Object, GetCursor<Object>> cursors) =>
      _MixedDictCursor(cursors);

  @reify
  int get length => _values.length;

  @reify
  Iterable<Key> get keys => _values.keys;

  Iterable<Value> get values => _values.values;

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
            Vec([
              Vec<dynamic>(<dynamic>['[]', key])
            ])
          }),
          changed: PathSet.from({
            const Vec(['keys']),
            const Vec(['length']),
          }),
        );
      } else {
        return Diff(
          changed: PathSet.from({
            Vec([
              Vec<dynamic>(<dynamic>['[]', key])
            ])
          }),
        );
      }
    }, none: () {
      if (!_values.containsKey(key)) {
        return const Diff();
      } else {
        return Diff(
          removed: PathSet.from({
            Vec([
              Vec<dynamic>(<dynamic>['[]', key])
            ])
          }),
          changed: PathSet.from({
            const Vec(['keys']),
            const Vec(['length']),
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
          Vec([key])
        }),
        changed: PathSet.from({
          const Vec(['keys']),
          const Vec(['length'])
        }),
      );
    } else {
      return const Diff();
    }
  }

  @override
  Iterable<MapEntry<Key, Value>> get entries => _values.entries;

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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    for (final entry in entries) {
      if (entry.value is! Diagnosticable) {
        properties.add(DiagnosticsProperty(entry.key.toString(), entry.value));
      }
    }
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return [
      for (final entry in entries)
        if (entry.value is Diagnosticable)
          (entry.value as Diagnosticable).toDiagnosticsNode(name: entry.key.toString())
    ];
  }
}

extension ManualDictCursorExtension<Key extends Object, Value> on Cursor<Dict<Key, Value>> {
  Cursor<Optional<Value>> operator [](Key key) => then(
        Lens(
          Vec([
            Vec<dynamic>(<dynamic>['[]', key])
          ]),
          (t) => t[key],
          (t, s) => t.mut_array_op(key, s(t[key])),
        ),
      );

  void operator []=(Key key, Value update) {
    mutResult(
      (obj) => DiffResult(
        obj.mut_array_op(key, Optional(update)),
        obj._mut_array_op_mutated(key, Optional(update)),
      ),
    );
  }
}

extension ManualDictGetCursorExtension<Key extends Object, Value> on GetCursor<Dict<Key, Value>> {
  GetCursor<Optional<Value>> operator [](Key key) {
    final thisCursor = this;
    if (thisCursor is _MixedDictCursor<Key, Value>) {
      final value = thisCursor.values[key];
      return value == null ? GetCursor(Optional.none()) : WrapOptionalCursor(value);
    }
    return then(
      Lens(
        Vec([
          Vec<dynamic>(<dynamic>['[]', key])
        ]),
        (t) => t[key],
        (t, s) => t.mut_array_op(key, s(t[key])),
      ),
    );
  }
}

class _MixedDictCursor<Key extends Object, Value>
    with GetCursor<Dict<Key, Value>>, DiagnosticableTreeMixin {
  final Map<Key, GetCursor<Value>> values;

  _MixedDictCursor(this.values);

  @override
  void Function() listen(void Function(Dict<Key, Value> old, Dict<Key, Value> nu, Diff diff) f) {
    final disposals = [
      for (final value in values.values)
        // TODO: incorrect
        value.listen((old, nu, diff) => f(read(Ctx.empty), read(Ctx.empty), Diff.allChanged()))
    ];
    return () {
      for (final disposal in disposals) {
        disposal();
      }
    };
  }

  @override
  Dict<Key, Value> read(Ctx ctx) {
    return Dict({for (final entry in values.entries) entry.key: entry.value.read(ctx)});
  }

  @override
  GetCursor<S1> thenGet<S1>(Getter<Dict<Key, Value>, S1> getter) {
    return GetCursor(getter.get(read(Ctx.empty)));
  }

  @override
  GetCursor<S1> thenOptGet<S1>(
    OptGetter<Dict<Key, Value>, S1> getter, {
    String Function()? errorMsg,
  }) {
    final result = getter.getOpt(read(Ctx.empty));
    assert(result.isPresent, errorMsg);
    return GetCursor(result.first);
  }
}
