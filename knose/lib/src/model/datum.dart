import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:meta/meta.dart';
import 'package:knose/model.dart';

part 'datum.g.dart';

@immutable
@reify
abstract class DataSource implements CtxElement {
  @reify
  GetCursor<Vec<Datum>> get data;
}

@immutable
@reify
abstract class Datum {
  const Datum();

  String name(Ctx ctx);

  PalType type(Ctx ctx);

  Cursor<PalValue>? build(Ctx ctx);
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
