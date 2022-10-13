import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/pal.dart' as pal;
import 'package:flutter/material.dart';

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
final datumOrDatumDatumID = pal.MemberID();
final datumOrDatumSubExprID = pal.MemberID();
final datumOrLiteralID = pal.MemberID();
final datumOrDef = pal.DataDef(
  tree: pal.RecordNode('DatumOr', {
    datumOrTypeID: const pal.LeafNode('type', pal.type),
    datumOrDefaultID: pal.LeafNode('defaultValue', pal.RecordAccess(datumOrTypeID)),
    datumOrDataID: pal.UnionNode('data', {
      datumOrDatumID: pal.RecordNode('datum', {
        datumOrDatumDatumID: pal.LeafNode('datum', pal.datumDef.asType()),
        datumOrDatumSubExprID: pal.LeafNode(
          'subExpr',
          pal.FnType(
            target: pal.unit,
            returnType: pal.RecordAccess(datumOrTypeID),
          ),
        ),
      }),
      datumOrLiteralID: pal.LeafNode('literal', pal.RecordAccess(datumOrTypeID)),
    }),
  }),
);

Cursor<Object>? evalDatumOr(Ctx ctx, Cursor<Object> datumOr) {
  return datumOr.recordAccess(datumOrDataID).dataCases(ctx, {
    datumOrDatumID: (obj) {
      final datum = obj.recordAccess(datumOrDatumDatumID).read(ctx) as model.Datum;
      final subExpr = obj.recordAccess(datumOrDatumSubExprID).read(ctx);
      var datumValue = datum.value(ctx);
      final datumType = datum.type(ctx);
      final datumOrType = datumOr.recordAccess(datumOrTypeID).read(ctx) as pal.Type;
      if (datumType.isConcrete && !datumOrType.isConcrete) {
        datumValue = datumValue?.wrap(datumType);
      }
      final result = datumValue == null ? null : subExpr.callFn(ctx, datumValue) as Cursor<Object>?;

      return result;
    },
    datumOrLiteralID: (obj) => obj,
  });
}

void setDatumOrDatum({
  required Ctx ctx,
  required Cursor<Object> datumOr,
  required model.Datum newDatum,
  Object subExpr = _id,
}) {
  datumOr.recordAccess(datumOrDataID).set(
        pal.UnionTag(
          datumOrDatumID,
          datumOrDef.instantiate(
            {
              datumOrDatumDatumID: newDatum,
              datumOrDatumSubExprID: _id,
            },
            at: [datumOrDataID, datumOrDatumID],
          ),
        ),
      );
}

Object _id(Ctx ctx, Object o) => o;

@reader
Widget _editDatumOr(
  BuildContext context, {
  required Cursor<Object> datumOr,
  required Ctx ctx,
  ButtonStyle? style,
}) {
  return TextButtonDropdown(
    style: (style ?? const ButtonStyle()).copyWith(
      minimumSize: style?.minimumSize ??
          MaterialStateProperty.all(
            Size(0, Theme.of(context).buttonTheme.height),
          ),
      padding: style?.padding ??
          MaterialStateProperty.all(const EdgeInsetsDirectional.only(start: 0, end: 0)),
    ),
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
                      onPressed: () => setDatumOrDatum(ctx: ctx, datumOr: datumOr, newDatum: datum),
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
        datumOrDatumID: (obj) =>
            (obj.recordAccess(datumOrDatumDatumID).read(ctx) as model.Datum).name(ctx),
        datumOrLiteralID: (_) => 'Literal',
      }),
    ),
  );
}
