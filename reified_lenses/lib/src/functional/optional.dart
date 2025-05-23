import 'package:ctx/ctx.dart';
import 'package:flutter/foundation.dart';
import 'package:reified_lenses/reified_lenses.dart';

class Optional<Value> extends Iterable<Value> {
  final Value? _value;

  const Optional(Value value) : _value = value;
  const Optional.none() : _value = null;
  const Optional.fromNullable(this._value);

  Value? get unwrap => _value;

  T cases<T>({required T Function(Value) some, required T Function() none}) =>
      _value == null ? none() : some(_value as Value);

  @override
  Optional<T> map<T>(T Function(Value) toElement) =>
      _value == null ? Optional.none() : Optional(toElement(_value as Value));

  Optional<T> flatMap<T>(Optional<T> Function(Value) toElement) =>
      _value == null ? Optional.none() : toElement(_value as Value);

  bool get isPresent => _value != null;

  void ifPresent(void Function(Value) f) {
    if (_value != null) f(_value as Value);
  }

  Value orElse(Value v) => _value == null ? v : _value!;

  @override
  String toString() => _value == null ? 'Optional.none' : 'Optional($_value)';

  @override
  Iterator<Value> get iterator => _value == null ? <Value>[].iterator : [_value as Value].iterator;

  @override
  int get hashCode => Object.hashAll(this);

  @override
  bool operator ==(Object other) {
    return other is Optional<Value> && _value == other._value;
  }
}

class WrapOptionalCursor<Value> with GetCursor<Optional<Value>>, DiagnosticableTreeMixin {
  final GetCursor<Value> _value;

  WrapOptionalCursor(this._value);

  @override
  void Function() listen(void Function(Optional<Value> old, Optional<Value> nu, Diff diff) f) {
    return _value.listen((old, nu, diff) {
      f(Optional(old), Optional(nu), diff.prepend(Vec(['value'])));
    });
  }

  @override
  Optional<Value> read(Ctx ctx) {
    return Optional(_value.read(ctx));
  }

  @override
  GetCursor<S1> thenGet<S1>(Getter<Optional<Value>, S1> getter) {
    // TODO: implement thenGet
    throw UnimplementedError();
  }

  @override
  GetCursor<S1> thenOptGet<S1>(OptGetter<Optional<Value>, S1> getter,
      {String Function()? errorMsg}) {
    // TODO: implement thenOptGet
    throw UnimplementedError();
  }
}

extension GetCursorOptional<T> on GetCursor<Optional<T>> {
  GetCursor<bool> get isEmpty => GetCursor.compute(
        (ctx) => this.read(ctx).isEmpty,
        ctx: Ctx.empty,
        compare: true,
      );

  GetCursor<T> get whenPresent {
    final thisCursor = this;
    if (thisCursor is WrapOptionalCursor<T>) return thisCursor._value;
    return thenOpt(
      OptLens(const Vec(['value']), (t) => t, (t, f) => t.map(f)),
      errorMsg: () => 'Tried to unwrap optional value which is not present.',
    );
  }

  GetCursor<bool> get isPresent =>
      GetCursor.compute((ctx) => this.read(ctx).isPresent, ctx: Ctx.empty, compare: true);

  T0 cases<T0>(
    Ctx ctx, {
    required T0 Function(GetCursor<T>) some,
    required T0 Function() none,
  }) {
    if (this.isEmpty.read(ctx)) {
      return none();
    } else {
      return some(this.whenPresent);
    }
  }
}

extension CursorOptional<T> on Cursor<Optional<T>> {
  Cursor<T> get whenPresent {
    return thenOpt(
      OptLens(const Vec(['value']), (t) => t, (t, f) => t.map(f)),
      errorMsg: () => 'Tried to unwrap optional value which is not present.',
    );
  }

  Cursor<T> orElse(T defaultValue) => then(Lens(
        const Vec(['value']),
        (t) => t.orElse(defaultValue),
        (t, f) => Optional(f(t.orElse(defaultValue))),
      ));

  Cursor<Optional<S>> optionalCast<S extends T>() => thenOpt(
        OptLens(
          const Vec(),
          (t) => t.unwrap is S? ? Optional(Optional.fromNullable(t.unwrap as S?)) : Optional.none(),
          (t, f) => f(t.map((t) => t as S)),
        ),
        errorMsg: () => 'Tried to cast cursor of current type ${this.type(Ctx.empty)} to $S',
      );

  T0 cases<T0>(
    Ctx ctx, {
    required T0 Function(Cursor<T>) some,
    required T0 Function() none,
  }) {
    if (this.isEmpty.read(ctx)) {
      return none();
    } else {
      return some(this.whenPresent);
    }
  }
}
