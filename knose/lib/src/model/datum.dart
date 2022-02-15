import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/pal.dart' as pal;
import 'package:meta/meta.dart';

@immutable
abstract class DataSource implements CtxElement {
  GetCursor<Vec<Datum>> get data;
}

@immutable
abstract class Datum {
  const Datum();

  String name(Ctx ctx);

  pal.Type type(Ctx ctx);

  Cursor<Object>? value(Ctx ctx);
}
