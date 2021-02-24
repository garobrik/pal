import 'package:reified_lenses/reified_lenses.dart';

part 'test.g.dart';

@reify
class Data<A> {
  static Lens<Data<A>, Data<A>> lens<A>() => Lens.identity();

  final A? a;
  final Data<A>? b;
  final int? c;
  final String? d;
  String get e => 'this';

  const Data({this.a, this.b, this.c, this.d});
}

Data<int> d = Data<int>();
int? a = Data.lens<int>().b.nonnull.b.nonnull.a.get(d);

