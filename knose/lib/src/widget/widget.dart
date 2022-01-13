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
final typeID = pal.MemberID();
final defaultDataID = pal.MemberID();
final buildID = pal.MemberID();
final def = pal.DataDef.record(
  name: 'Widget',
  members: [
    pal.Member(id: nameID, name: 'name', type: pal.text),
    pal.Member(id: typeID, name: 'type', type: pal.type),
    pal.Member(id: defaultDataID, name: 'defaultDataID', type: pal.RecordAccess(typeID)),
    pal.Member(
      id: buildID,
      name: 'build',
      type: pal.FunctionType(
        returnType: flutterWidgetDef.asType(),
        target: pal.cursorType(pal.RecordAccess(typeID)),
      ),
    ),
  ],
);

typedef DefaultDataFn = Object Function({required Ctx ctx});

typedef BuildFn = flutter.Widget Function(
  Cursor<Object> data, {
  required Ctx ctx,
});

final instance = instanceDef.asType();
final instanceIDID = pal.MemberID();
final instanceWidgetID = pal.MemberID();
final instanceDataID = pal.MemberID();
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
      id: instanceDataID,
      name: 'data',
      type: pal.RecordAccess(typeID, target: pal.RecordAccess(instanceWidgetID)),
    ),
  ],
);

final flutterWidgetDef = pal.InterfaceDef(name: 'FlutterWidget', members: []);

Object defaultInstance(Ctx ctx, Object widget) {
  final defaultData = widget.recordAccess(defaultDataID) as DefaultDataFn;
  return instanceDef.instantiate({
    instanceIDID: ID.create(),
    instanceWidgetID: widget,
    instanceDataID: defaultData(ctx: ctx),
  });
}
