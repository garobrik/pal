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

  void ifPresent<T>(void Function(Value) f) {
    if (_value != null) f(_value!);
  }

  Value orElse(Value v) => _value == null ? v : _value!;
}

