import 'package:uuid/uuid.dart';

class UUID {
  static const uuid = Uuid();

  final String id;

  UUID() : id = uuid.v4();

  UUID.from(this.id);

  @override
  bool operator ==(Object? other) => other is UUID && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$runtimeType($id)';
}
