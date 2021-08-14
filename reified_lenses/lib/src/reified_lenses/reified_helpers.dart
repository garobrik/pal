import 'package:reified_lenses/reified_lenses.dart';

abstract class ReifiedHelpers {
  static S? caseTo<T, S>(T t) => t is S ? t : null;
  static DiffResult<T> caseFrom<T, S extends T>(DiffResult<S> s) => s;
  static DiffResult<S?> caseUpdate<T, S>(T old, T nu, Diff diff) =>
      DiffResult(nu is S ? nu : null, diff);
}
