class DartFn {
  final String id;
  final String? label;

  const DartFn(this.id, [this.label]);
}

class Hash {
  static int combine(int hash, int value) {
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  static int all(Object? obj1, Object? obj2) {
    return finish(combine(obj2.hashCode, combine(obj1.hashCode, 0)));
  }
}
