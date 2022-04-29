import 'package:ctx/ctx.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/pal.dart' as pal;
import 'package:flutter/widgets.dart' as flutter;

class ID extends pal.ID<Object> {
  static const namespace = 'widgets';

  ID.create() : super.create(namespace: namespace);
  ID.from(String key) : super.from(namespace, key);
}

class RootID extends pal.ID<Object> {
  static const namespace = 'root_widgets';

  RootID.create() : super.create(namespace: namespace);
  RootID.from(String key) : super.from(namespace, key);
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
    pal.Member(
      id: defaultDataID,
      name: 'defaultDataID',
      type: pal.FnType(returnType: pal.RecordAccess(typeID)),
    ),
    pal.Member(
      id: buildID,
      name: 'build',
      type: pal.FnType(
        returnType: flutterWidgetDef.asType(),
        target: pal.cursorType(pal.RecordAccess(typeID)),
      ),
    ),
  ],
);

final rootIDDef =
    pal.InterfaceDef(name: 'RootWidgetID', members: [pal.Member(name: 'id', type: pal.text)]);

final rootIDID = pal.MemberID();
final rootNameID = pal.MemberID();
final rootTopLevelID = pal.MemberID();
final rootModeID = pal.MemberID();
final rootInstanceID = pal.MemberID();
final rootDef = pal.DataDef.record(
  name: 'RootWidget',
  members: [
    pal.Member(id: rootIDID, name: 'id', type: rootIDDef.asType()),
    pal.Member(id: rootNameID, name: 'name', type: pal.text),
    pal.Member(id: rootTopLevelID, name: 'topLevel', type: pal.boolean),
    pal.Member(id: rootModeID, name: 'mode', type: pal.optionType(modeDef.asType())),
    pal.Member(id: rootInstanceID, name: 'instance', type: instanceDef.asType()),
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
  final defaultData = widget.recordAccess(defaultDataID);
  return instanceDef.instantiate({
    instanceIDID: ID.create(),
    instanceWidgetID: widget,
    instanceDataID: defaultData.callFn(ctx, pal.unit),
  });
}

Object rootInstance({
  required Ctx ctx,
  required Object widget,
  required String name,
  required Optional<Mode> mode,
  bool topLevel = true,
}) {
  final defaultData = widget.recordAccess(defaultDataID);

  final instance = instanceDef.instantiate({
    instanceIDID: ID.create(),
    instanceWidgetID: widget,
    instanceDataID: defaultData.callFn(ctx, pal.unit),
  });

  return rootDef.instantiate({
    rootIDID: RootID.create(),
    rootNameID: name,
    rootTopLevelID: topLevel,
    rootModeID: mode,
    rootInstanceID: instance,
  });
}

final modeDef = pal.DataDef.unit('WidgetMode');

enum Mode {
  edit,
  view,
}

class _WidgetModeCtx extends CtxElement {
  final Mode mode;

  _WidgetModeCtx(this.mode);
}

extension WidgetModeCtxExtension on Ctx {
  Ctx withWidgetMode(Mode mode) => withElement(_WidgetModeCtx(mode));
  Mode get widgetMode => get<_WidgetModeCtx>()?.mode ?? Mode.view;
}

final functionalWidget = def.instantiate({
  nameID: 'FunctionalWidget',
  typeID: pal.FnType(returnType: flutterWidgetDef.asType()),
  defaultDataID: (Ctx ctx, Object _) => (Ctx ctx, Object _) => const Text('default'),
  buildID: (Ctx ctx, Object fn) => (fn as GetCursor<Object>).callFn(ctx, pal.unit),
});

Object functional(Ctx ctx, Widget Function(Ctx) fn) =>
    (defaultInstance(ctx, functionalWidget) as Dict<pal.MemberID, Object>).put(
      instanceDataID,
      (Ctx ctx, Object _) => fn(ctx),
    );
