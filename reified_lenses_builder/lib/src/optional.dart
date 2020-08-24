library optional;

import 'package:meta/meta.dart';
import 'package:reified_lenses/reified_lenses.dart';

@immutable
@reified_lens
class Optional<Value> extends Iterable<Value> {
  final Value _value;

  const Optional.empty() : _value = null;

  Optional(Value value)
      : assert(value != null, 'Initialized Optional with null value.'),
        _value = value;

  const Optional.nullable(this._value);

  factory Optional.ifTrue(bool test, Value value) =>
      test ? Optional(value) : Optional.empty();
  factory Optional.ifLazy(bool test, Value Function() value) =>
      test ? Optional(value()) : Optional.empty();

  Value get value {
    assert(_value != null, 'Attempted to access value of empty Optional.');
    return _value;
  }

  @override
  bool get isEmpty => _value == null;
  @override
  bool get isNotEmpty => _value != null;
  bool get hasValue => _value != null;

  Optional<B> map<B>(B Function(Value a) f) =>
      isEmpty ? Optional.empty() : Optional(f(value));

  Optional<B> flatMap<B>(Optional<B> Function(Value a) f) =>
      isEmpty ? Optional.empty() : f(value);

  Value or(Value value) => isEmpty ? value : this.value;
  Value orLazy(Value Function() value) => isEmpty ? value() : this.value;

  @override
  bool operator ==(Object other) => other is Optional && _value == other._value;
  @override
  int get hashCode => isEmpty ? 0 : _value.hashCode;

  @override
  Iterator<Value> get iterator => _Iterator(this);
}

class _Iterator<Value> implements Iterator<Value> {
  final Optional<Value> optional;
  int index;

  _Iterator(this.optional) : index = -1;

  @override
  Value get current =>
      (optional.hasValue && index == 0) ? optional.value : null;

  @override
  bool moveNext() {
    index++;
    return current != null;
  }
}
