import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/pal.dart' as pal;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'datum_or.g.dart';

class _DatumOrDispatch {
  const _DatumOrDispatch._();

  pal.DataType call(pal.Type type) => datumOrDef.asType(assignments: {datumOrTypeID: type});

  Object instantiate({required pal.Type type, required Object data}) => datumOrDef.instantiate({
        datumOrTypeID: type,
        datumOrDefaultID: data,
        datumOrDataID: pal.UnionTag(datumOrLiteralID, data)
      });
}

const datumOr = _DatumOrDispatch._();

final datumOrTypeID = pal.MemberID();
final datumOrDataID = pal.MemberID();
final datumOrDefaultID = pal.MemberID();
final datumOrDatumID = pal.MemberID();
final datumOrLiteralID = pal.MemberID();
final datumOrDef = pal.DataDef(
  tree: pal.RecordNode('DatumOr', {
    datumOrTypeID: const pal.LeafNode('type', pal.type),
    datumOrDefaultID: pal.LeafNode('defaultValue', pal.RecordAccess(datumOrTypeID)),
    datumOrDataID: pal.UnionNode('data', {
      datumOrDatumID: pal.LeafNode('datum', pal.datumDef.asType()),
      datumOrLiteralID: pal.LeafNode('literal', pal.RecordAccess(datumOrTypeID)),
    }),
  }),
);

Cursor<Object>? evalDatumOr(Ctx ctx, Cursor<Object> datumOr) {
  return datumOr.recordAccess(datumOrDataID).dataCases(ctx, {
    datumOrDatumID: (obj) {
      final datum = obj.read(ctx) as model.Datum;
      final result = datum.value(ctx);
      final datumType = datum.type(ctx);
      final datumOrType = datumOr.recordAccess(datumOrTypeID).read(ctx) as pal.Type;
      if (datumType.isConcrete && !datumOrType.isConcrete) {
        return result?.wrap(datumType);
      }
      return result;
    },
    datumOrLiteralID: (obj) => obj,
  });
}

@reader
Widget _editDatumOr({
  required Cursor<Object> datumOr,
  required Ctx ctx,
  ButtonStyle? style,
}) {
  return TextButtonDropdown(
    style: style,
    dropdown: IntrinsicWidth(
      child: ReaderWidget(
        ctx: ctx,
        builder: (_, ctx) {
          final datumOrType = datumOr.recordAccess(datumOrTypeID).read(ctx) as pal.Type;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final dataSource in ctx.ofType<model.DataSource>())
                for (final datum in dataSource.data.read(ctx))
                  if (datum.type(ctx).assignableTo(ctx, datumOrType))
                    TextButton(
                      onPressed: () => datumOr
                          .recordAccess(datumOrDataID)
                          .set(pal.UnionTag(datumOrDatumID, datum)),
                      child: Text(datum.name(ctx)),
                    ),
              TextButton(
                onPressed: () => datumOr.recordAccess(datumOrDataID).set(pal.UnionTag(
                      datumOrLiteralID,
                      datumOr.recordAccess(datumOrDefaultID).read(Ctx.empty),
                    )),
                child: const Text('Literal'),
              )
            ],
          );
        },
      ),
    ),
    child: Text(
      datumOr.recordAccess(datumOrDataID).dataCases(ctx, {
        datumOrDatumID: (obj) => (obj.read(ctx) as model.Datum).name(ctx),
        datumOrLiteralID: (_) => 'Literal',
      }),
    ),
  );
}
