import 'package:ctx/ctx.dart';
import 'package:reified_lenses/reified_lenses.dart';

class Optional<Value> {
  final Value? _value;

  const Optional(Value value) : _value = value;
  const Optional.none() : _value = null;
  const Optional.fromNullable(this._value);

  Value? get unwrap => _value;

  T cases<T>({required T Function(Value) some, required T Function() none}) =>
      _value == null ? none() : some(_value!);

  Optional<T> map<T>(T Function(Value) f) =>
      _value == null ? Optional.none() : Optional(f(_value!));

  bool get isPresent => _value != null;

  void ifPresent<T>(void Function(Value) f) {
    if (_value != null) f(_value!);
  }

  Value orElse(Value v) => _value == null ? v : _value!;

  @override
  String toString() => _value == null ? 'Optional.none' : 'Optional($_value)';
}

extension GetCursorOptional<T> on GetCursor<Optional<T>> {
  GetCursor<T> get whenPresent {
    assert(this.read(Ctx.empty).unwrap != null);
    return partial(
      to: (t) => t.unwrap,
      update: (old, nu, diff) => DiffResult(nu.unwrap, diff),
    );
  }

  GetCursor<bool> get isPresent =>
      GetCursor.compute((ctx) => this.read(ctx).isPresent, ctx: Ctx.empty, compare: true);
}

extension CursorOptional<T> on Cursor<Optional<T>> {
  Cursor<T> get whenPresent {
    assert(this.read(Ctx.empty).unwrap != null);
    return partial(
      to: (t) => t.unwrap,
      from: (diff) => DiffResult(Optional(diff.value), diff.diff),
      update: (old, nu, diff) => DiffResult(nu.unwrap, diff),
    );
  }

  Cursor<T> orElse(T defaultValue) => then(Lens(
        Path.empty(),
        (t) => t.orElse(defaultValue),
        (t, f) => Optional(f(t.orElse(defaultValue))),
      ));

  Cursor<Optional<S>> optionalCast<S extends T>() {
    if (S == T) return this as Cursor<Optional<S>>;
    assert(
      this.read(Ctx.empty).unwrap is S?,
      'Tried to cast cursor of current type ${this.type(Ctx.empty)} to $S',
    );
    return partial(
      to: (s) => s.unwrap is S? ? Optional.fromNullable(s.unwrap as S?) : null,
      from: (s1) => s1,
      update: (_, nu, diff) =>
          DiffResult(nu.unwrap is S? ? Optional.fromNullable(nu.unwrap as S?) : null, diff),
    );
  }
}
