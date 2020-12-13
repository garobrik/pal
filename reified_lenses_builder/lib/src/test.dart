import 'package:reified_lenses/reified_lenses.dart';

part 'test.g.dart';

@reified_lens
class Data<A> {
  static Lens<Data<A>, Data<A>> lens<A>() => Lens.identity();

  final A? a;
  final Data<A>? b;
  @mutater
  final int? c;
  @getter
  final String? d;
  @getter
  String get e => 'this';

  const Data({this.a, this.b, this.c, this.d});
}

Data<int> d = Data<int>();
int? a = Data.lens<int>().b.nonnull.b.nonnull.a.get(d);

