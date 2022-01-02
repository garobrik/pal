import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/pal.dart' as pal;
import 'package:flutter/widgets.dart' as flutter;

class ID extends pal.ID<Object> {
  static const namespace = 'widgets';

  ID.create() : super.create(namespace: namespace);
  ID.from(String key) : super.from(namespace, key);
}

final idDef = pal.InterfaceDef(name: 'WidgetID', members: [pal.Member(name: 'id', type: pal.text)]);

final nameID = pal.MemberID();
final fieldsID = pal.MemberID();
final defaultFieldsID = pal.MemberID();
final buildID = pal.MemberID();
final def = pal.DataDef.record(
  name: 'Widget',
  members: [
    pal.Member(id: nameID, name: 'name', type: pal.text),
    pal.Member(id: fieldsID, name: 'fields', type: const pal.Map(pal.text, pal.typeType)),
    pal.Member(
      id: defaultFieldsID,
      name: 'defaultFields',
      type: pal.FunctionType(
        returnType: pal.RecordAccess(fieldsID),
        target: pal.unit,
      ),
    ),
    pal.Member(
      id: buildID,
      name: 'build',
      type: pal.FunctionType(
        returnType: flutterWidgetDef.asType(),
        target: pal.Map(pal.text, pal.cursorDef.asType()),
      ),
    ),
  ],
);

typedef DefaultFieldsFn = Dict<Object, Object> Function({required Ctx ctx});

typedef BuildFn = flutter.Widget Function(
  Dict<String, Cursor<Object>> fields, {
  required Ctx ctx,
});

final instanceIDID = pal.MemberID();
final instanceWidgetID = pal.MemberID();
final instanceFieldsID = pal.MemberID();
final instanceDef = pal.DataDef.record(
  name: 'WidgetInstance',
  members: [
    pal.Member(
      id: instanceIDID,
      name: 'id',
      type: idDef.asType(),
    ),
    pal.Member(
      id: instanceWidgetID,
      name: 'widget',
      type: def.asType(),
    ),
    pal.Member(
      id: instanceFieldsID,
      name: 'fields',
      type: pal.Map(pal.text, pal.Union({pal.datumDef.asType(), pal.any})),
    ),
  ],
);

final flutterWidgetDef = pal.InterfaceDef(name: 'FlutterWidget', members: []);

Object defaultInstance(Ctx ctx, Object widget) {
  final defaultFields = widget.recordAccess(defaultFieldsID) as DefaultFieldsFn;
  return Dict({
    instanceIDID: ID.create(),
    instanceWidgetID: widget,
    instanceFieldsID: defaultFields(ctx: ctx)
  });
}
