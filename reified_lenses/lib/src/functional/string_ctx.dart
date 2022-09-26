import 'package:meta/meta.dart';

abstract class ToStringCtx {
  @override
  String toString() => toStringCtx();

  String toStringCtx() {
    final buffer = StringBuffer();
    doStringCtx(buffer, 0);
    return buffer.toString();
  }

  @protected
  void doStringCtx(StringBuffer buffer, int leading);
}

void printCtx(Object obj) {
  if (obj is ToStringCtx) {
    print(obj.toStringCtx());
  } else {
    print(obj);
  }
}
