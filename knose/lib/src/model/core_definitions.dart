import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/model.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'dart:core' as dart;
import 'dart:core';

final PalDB coreDB = () {
  final db = Cursor(const PalDB());
  for (final interface in interfaceTypes) {
    db.update(interface.id, interface);
  }

  return db.read(Ctx.empty);
}();

final interfaceTypes = <InterfaceDef>[
  palIDDef,
  widgetIDDef,
  richTextDef,
  widgetDef,
  cursorDef,
];

final memberIDDef = InterfaceDef(name: 'MemberID', members: []);

final optionMemberID = MemberID();
final optionDef = InterfaceDef(
  name: 'Option',
  members: [PalMember(id: optionMemberID, name: 'type', type: typeType)],
);

PalValue mkPalOption(PalValue? value, PalType type) =>
    PalValue(optionDef.asType({optionMemberID: type}), Optional.fromNullable(value));

extension OptionalPalValueCursorExtension on Cursor<Optional<PalValue>> {
  Cursor<PalValue> asPalOption(PalType type) => partial(
        to: (opt) => PalValue(optionDef.asType({optionMemberID: type}), opt),
        from: (diff) => DiffResult(diff.value.value as Optional<PalValue>, diff.diff),
      );
}

extension OptionalPalValueExtension on Optional<PalValue> {
  PalValue asPalOption(PalType type) => PalValue(optionDef.asType({optionMemberID: type}), this);
}

TypeID addStructType(Cursor<PalDB> db, String name, dart.List<PalMember> members) {
  final interface = InterfaceDef(name: name, members: members);
  db.update(interface.id, interface);

  final dataType = PalValue(MapType(memberIDDef.asType(), typeType),
      {for (final member in members) member.id: member.type});

  final impl = PalImpl(implementer: dataType, implemented: interface.asType(), implementations: {});
  db.update(impl.id, impl);

  return interface.id;
}

final palIDDef = InterfaceDef(
  name: 'PalID',
  members: [
    PalMember(name: 'namespace', type: textType),
    PalMember(name: 'id', type: textType),
  ],
);

final tableIDDef = InterfaceDef(
  name: 'TableID',
  members: [PalMember(name: 'id', type: textType)],
);

class WidgetID extends PalID<PalValue> {
  static const namespace = 'widgets';

  WidgetID.create() : super.create(namespace: namespace);
  WidgetID.from(String key) : super.from(namespace, key);
}

final widgetIDDef =
    InterfaceDef(name: 'WidgetID', members: [PalMember(name: 'id', type: textType)]);

final richTextDef = InterfaceDef(name: 'RichText', members: [
  PalMember(name: 'elements', type: UnionType({textType, widgetDef.asType()}))
]);

final cursorTypeMemberID = MemberID();
final cursorDef = InterfaceDef(
  name: 'Cursor',
  members: [PalMember(id: cursorTypeMemberID, name: 'type', type: typeType)],
);

final datumDef = InterfaceDef(
  name: 'Datum',
  members: [],
);

final widgetDef = InterfaceDef(
  name: 'Widget',
  members: [
    PalMember(name: 'name', type: textType),
    PalMember(name: 'fields', type: const MapType(textType, typeType)),
    PalMember(
      name: 'defaultFields',
      type: const FunctionType(returnType: MapType(textType, anyType), target: unitType),
    ),
    PalMember(
      name: 'build',
      type: FunctionType(
        returnType: flutterWidgetDef.asType(),
        target: MapType(textType, cursorDef.asType()),
      ),
    ),
  ],
);

typedef WidgetBuildFn = flutter.Widget Function(
  Dict<String, Cursor<PalValue>> fields, {
  required Ctx ctx,
});

final widgetInstanceDef = InterfaceDef(
  name: 'WidgetInstance',
  members: [
    PalMember(
      name: 'id',
      type: widgetIDDef.asType(),
    ),
    PalMember(
      name: 'widget',
      type: widgetDef.asType(),
    ),
    PalMember(
      name: 'fields',
      type: MapType(textType, UnionType({datumDef.asType(), anyType})),
    ),
  ],
);

final flutterWidgetDef = InterfaceDef(name: 'FlutterWidget', members: []);

PalValue defaultInstance(Ctx ctx, PalValue widget) {
  assert(widget.type.assignableTo(ctx, widgetDef.asType()));

  final defaultFields =
      widget.recordAccess<Dict<String, PalValue> Function({required Ctx ctx})>('defaultFields');
  return PalValue(
    widgetInstanceDef.asType(),
    Dict({'id': WidgetID.create(), 'widget': widget, 'fields': defaultFields(ctx: ctx)}),
  );
}

final tableDef = InterfaceDef(name: 'Table', members: []);
final columnIDDef = InterfaceDef(name: 'ColumnID', members: []);
final rowIDDef = InterfaceDef(name: 'RowID', members: []);

final columnTypeDataID = MemberID();
final columnTypeConfigID = MemberID();
final columnTypeDef = InterfaceDef(
  name: 'ColumnType',
  members: [
    PalMember(id: columnTypeDataID, name: 'dataType', type: typeType),
    PalMember(id: columnTypeConfigID, name: 'configType', type: typeType),
    PalMember(name: 'defaultConfig', type: MemberAccess(columnTypeConfigID)),
    PalMember(
      name: 'getData',
      type: FunctionType(
        returnType: cursorDef.asType({cursorTypeMemberID: MemberAccess(columnTypeDataID)}),
        target: PalValue(
          const MapType(textType, typeType),
          Dict({
            'rowID': rowIDDef.asType(),
            'config': cursorDef.asType({cursorTypeMemberID: MemberAccess(columnTypeConfigID)}),
          }),
        ),
      ),
    ),
    PalMember(
      name: 'getWidget',
      type: FunctionType(
        returnType: flutterWidgetDef.asType(),
        target: PalValue(
          const MapType(textType, typeType),
          Dict({
            'rowData': cursorDef.asType({cursorTypeMemberID: MemberAccess(columnTypeDataID)}),
            'config': cursorDef.asType({cursorTypeMemberID: MemberAccess(columnTypeConfigID)}),
          }),
        ),
      ),
    )
  ],
);

typedef ColumnGetDataFn = Cursor<PalValue> Function(
  Dict<String, Object>, {
  required Ctx ctx,
});

typedef ColumnGetWidgetFn = flutter.Widget Function(
  Dict<String, Cursor<PalValue>>, {
  required Ctx ctx,
});
