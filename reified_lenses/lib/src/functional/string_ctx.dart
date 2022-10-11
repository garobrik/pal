import 'package:meta/meta.dart';

abstract class ToStringCtx {
  @protected
  void doStringCtx(StringBuffer buffer, int leading);
}

void printCtx(Object obj) => print(obj.toStringCtx());

extension ToStringCtxExtension on Object {
  String toStringCtx() {
    final buffer = StringBuffer();
    doStringCtx(this, buffer, 0);
    return buffer.toString();
  }
}

void doStringCtx(Object obj, StringBuffer buffer, int leading) {
  if (obj is ToStringCtx) {
    obj.doStringCtx(buffer, leading);
  } else if (obj is Iterable) {
    obj.doStringCtx(buffer, leading);
  } else {
    buffer.write(obj.toString());
  }
}

extension IterableToStringCtx<T> on Iterable<T> {
  void doStringCtx(StringBuffer buffer, int leading) => buffer.write('$this');
}
