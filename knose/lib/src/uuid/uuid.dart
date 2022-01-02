import 'package:uuid/uuid.dart';

abstract class UUID<T extends UUID<dynamic>> extends Comparable<T> {
  static const _uuid = Uuid();

  final String id;

  UUID() : id = _uuid.v4();

  UUID.from(this.id);

  @override
  bool operator ==(Object other) => other is T && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$runtimeType($id)';

  @override
  int compareTo(T other) {
    return id.compareTo(other.id);
  }

  dynamic toJson() => id;
}
