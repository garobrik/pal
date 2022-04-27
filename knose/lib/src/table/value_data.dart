import 'package:ctx/ctx.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/table.dart';
import 'package:knose/pal.dart' as pal;
import 'package:knose/widget.dart' as widget;

pal.Value valueTableData({
  required pal.Type valueType,
  required String name,
  required Widget Function(Ctx ctx, Object rowData) getWidget,
  required Object defaultValue,
}) {
  return pal.Value(
    valueTableDataDef.asType(),
    Dict({
      valueTableDataTypeID: valueType,
      valueTableDataNameID: name,
      valueTableDataDefaultID: defaultValue,
      valueTableDataGetWidgetID: getWidget,
    }),
  );
}

final valueTableDataTypeID = pal.MemberID();
final valueTableDataNameID = pal.MemberID();
final valueTableDataDefaultID = pal.MemberID();
final valueTableDataGetWidgetID = pal.MemberID();
final valueTableDataGetWidgetType = pal.MemberID();
final valueTableDataDef = pal.DataDef.record(name: 'ValueTableData', members: [
  pal.Member(id: valueTableDataTypeID, name: 'valueType', type: pal.type),
  pal.Member(id: valueTableDataNameID, name: 'name', type: pal.text),
  pal.Member(
    id: valueTableDataDefaultID,
    name: 'valueDefault',
    type: pal.RecordAccess(valueTableDataTypeID),
  ),
  pal.Member(
    id: valueTableDataGetWidgetID,
    name: 'getWidget',
    type: pal.FnType(
      returnType: widget.flutterWidgetDef.asType(),
      target: pal.cursorType(pal.RecordAccess(valueTableDataTypeID)),
    ),
  ),
]);

final valueTableDataImpl = pal.Impl(
  implemented: tableDataDef.asType({tableDataImplementerID: valueTableDataDef.asType()}),
  implementations: Dict({
    tableDataGetTypeID: pal.Literal(
      tableDataGetTypeType,
      (Ctx ctx, Object arg) =>
          (arg as GetCursor<Object>).recordAccess(valueTableDataTypeID).read(ctx),
    ),
    tableDataGetNameID: pal.Literal(
      tableDataGetNameType,
      (Ctx ctx, Object arg) =>
          (arg as GetCursor<Object>).recordAccess(valueTableDataNameID).read(ctx),
    ),
    tableDataGetDefaultID: pal.Literal(
      tableDataGetDefaultType,
      (Ctx ctx, Object arg) =>
          (arg as GetCursor<Object>).recordAccess(valueTableDataDefaultID).read(ctx),
    ),
    tableDataGetWidgetID: pal.Literal(
      tableDataGetWidgetType,
      (Ctx ctx, Object args) {
        final impl = args.mapAccess('impl').unwrap! as Cursor<Object>;
        final getWidget = impl.recordAccess(valueTableDataGetWidgetID).read(ctx);
        return getWidget.callFn(ctx, args.mapAccess('rowData').unwrap!);
      },
    ),
    tableDataGetConfigID: pal.Literal(
      tableDataGetConfigType,
      (Ctx _, Object __) => const Optional<Widget>.none(),
    ),
  }),
);

final textTableData = valueTableData(
  valueType: pal.text,
  name: 'Text',
  getWidget: (ctx, obj) => StringField(obj as Cursor<Object>, ctx: ctx),
  defaultValue: '',
);
final numberTableData = valueTableData(
  valueType: pal.optionType(pal.number),
  name: 'Number',
  getWidget: (ctx, obj) => NumField(obj as Cursor<Object>, ctx: ctx),
  defaultValue: const Optional<Object>.none(),
);
final booleanTableData = valueTableData(
  valueType: pal.boolean,
  name: 'Checkbox',
  getWidget: (ctx, obj) => BoolCell(obj as Cursor<Object>, ctx: ctx),
  defaultValue: false,
);
