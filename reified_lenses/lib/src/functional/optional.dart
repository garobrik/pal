import 'package:reified_lenses/reified_lenses.dart';

class Optional<Value> {
  final Value? _value;

  Optional(Value value): assert(value != null), _value = value;
  const Optional.none() : _value = null;

  Value? get unwrap => _value;

  T cases<T>(T Function(Value) some, T Function() none) => _value == null ? none() : some(_value!);
}
