import 'package:test/test.dart';

void main() {
  test('evaluation', () {});
}

// let x: T = y in b
// (\x: T -> b)(y)
// letIn = \T: Type -> \B: Type -> \y: T -> \f: (T -> B) -> f(y)
// letIn Type Type (T: Type -> T -> T -> T) \Bool: Type ->
// letIn Bool Type (\T: Type -> a: T -> b: T -> a) \true: Bool ->
// letIn Bool Type (\T: Type -> a: T -> b: T -> b) \false: Bool ->
// letIn (T: Type -> Bool -> T -> T -> T) Type (\T: Type -> \c: Bool -> \a: T -> \b: T -> c T a b) \if: ... ->
// if Type false Type (Type -> Type)
