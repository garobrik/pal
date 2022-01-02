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

  Cursor<Object>? build(Ctx ctx);
}

// @immutable
// @reify
// class Literal extends Datum with _LiteralMixin {
//   const Literal({
//     required this.typeData,
//     required this.data,
//     required this.fieldName,
//   });

//   @override
//   final String fieldName;

//   @override
//   final Object data;

//   @override
//   final PalType typeData;

//   @override
//   PalType type(Ctx ctx) => typeData;

//   @override
//   Cursor<Object>? build(Reader reader, Ctx ctx) {
//     return ctx.state.getNode(nodeView).fields[fieldName].whenPresent.cast<Literal>().data;
//   }

//   @override
//   String name(Reader reader, Ctx ctx) => 'Literal';
// }
