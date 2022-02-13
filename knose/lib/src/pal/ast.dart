import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

abstract class Traversible {
  Object traverse(Object Function(Object) f);
}

Object doTraverse(Object obj, Object Function(Object) f) {
  if (obj is Traversible) {
    return obj.traverse(f);
  } else if (obj is Map<Object, Object>) {
    return {for (final entry in obj.entries) doTraverse(entry.key, f): doTraverse(entry.value, f)};
  } else if (obj is Dict<Object, Object>) {
    return Dict(
      {for (final entry in obj.entries) doTraverse(entry.key, f): doTraverse(entry.value, f)},
    );
  } else if (obj is List<Object>) {
    return [for (final entry in obj) doTraverse(entry, f)];
  } else if (obj is Vec<Object>) {
    return Vec([for (final entry in obj) doTraverse(entry, f)]);
  } else {
    return f(obj);
  }
}
