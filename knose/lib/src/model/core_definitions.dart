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
  for (final impl in implementations) {
    db.update(impl.id, impl);
  }

  return db.read(Ctx.empty);
}();

final interfaceTypes = <InterfaceDef>[
  palIDDef,
  widgetIDDef,
  richTextDef,
  columnImplDef,
  cursorDef,
];
final implementations = <PalImpl>[
  valueColumnImpl,
  dataColumnImpl,
];

final memberIDDef = InterfaceDef(name: 'MemberID', members: []);

final optionTypeID = MemberID();
final optionValueID = MemberID();
final optionSomeID = MemberID();
final optionNoneID = MemberID();
final optionDef = DataDef(
  name: 'Option',
  tree: RecordNode({
    optionTypeID: DataTreeElement('T', LeafNode(typeType)),
    optionValueID: DataTreeElement(
      'value',
      UnionNode({
        optionSomeID: DataTreeElement('some', LeafNode(RecordAccess(optionTypeID))),
        optionNoneID: DataTreeElement('none', LeafNode(unitType)),
      }),
    )
  }),
);

PalType optionType(PalType type) => optionDef.asType({optionTypeID: type});

// Object mkPalOption(Object? value, PalType type) =>
//     {optionTypeID: type, optionValueID: Pair(value != null ? optionSomeID : optionNoneID, value)};

// extension OptionalPalValueCursorExtension on Cursor<Optional<Object>> {
//   Cursor<Object> asPalOption(PalType type) => partial(
//         to: (opt) => mkPalOption(opt.unwrap, type),
//         from: (diff) {
//           final pair = diff.value.recordAccess(optionValueID) as Pair<MemberID, Object?>;
//           if (pair.first == optionSomeID) {
//             return DiffResult(Optional(pair.second!), diff.diff);
//           } else {
//             return DiffResult(const Optional.none(), diff.diff);
//           }
//         },
//       );
// }

// extension OptionalPalValueExtension on Optional<PalValue> {
//   PalValue asPalOption(PalType type) => PalValue(optionDef.asType({optionTypeID: type}), this);
// }

final palIDDef = InterfaceDef(
  name: 'PalID',
  members: [
    PalMember(name: 'namespace', type: textType),
    PalMember(name: 'id', type: textType),
  ],
);

final tableIDDef = DataDef.record(
  name: 'TableID',
  members: [PalMember(name: 'id', type: textType)],
);

class WidgetID extends PalID<Object> {
  static const namespace = 'widgets';

  WidgetID.create() : super.create(namespace: namespace);
  WidgetID.from(String key) : super.from(namespace, key);
}

final widgetIDDef =
    InterfaceDef(name: 'WidgetID', members: [PalMember(name: 'id', type: textType)]);

final richTextDef = InterfaceDef(name: 'RichText', members: [
  PalMember(name: 'elements', type: UnionType({textType, widgetDef.asType()}))
]);

PalType cursorType(PalType type) => cursorDef.asType({cursorTypeID: type});
final cursorTypeID = MemberID();
final cursorDef = InterfaceDef(
  name: 'Cursor',
  members: [PalMember(id: cursorTypeID, name: 'type', type: typeType)],
);

final datumDef = InterfaceDef(
  name: 'Datum',
  members: [],
);

final widgetNameID = MemberID();
final widgetFieldsID = MemberID();
final widgetDefaultFieldsID = MemberID();
final widgetBuildID = MemberID();
final widgetDef = DataDef.record(
  name: 'Widget',
  members: [
    PalMember(id: widgetNameID, name: 'name', type: textType),
    PalMember(id: widgetFieldsID, name: 'fields', type: const MapType(textType, typeType)),
    PalMember(
      id: widgetDefaultFieldsID,
      name: 'defaultFields',
      type: FunctionType(
        returnType: RecordAccess(widgetFieldsID),
        target: unitType,
      ),
    ),
    PalMember(
      id: widgetBuildID,
      name: 'build',
      type: FunctionType(
        returnType: flutterWidgetDef.asType(),
        target: MapType(textType, cursorDef.asType()),
      ),
    ),
  ],
);

typedef WidgetDefaultFieldsFn = Dict<Object, Object> Function({required Ctx ctx});

typedef WidgetBuildFn = flutter.Widget Function(
  Dict<String, Cursor<Object>> fields, {
  required Ctx ctx,
});

final widgetInstanceIDID = MemberID();
final widgetInstanceWidgetID = MemberID();
final widgetInstanceFieldsID = MemberID();
final widgetInstanceDef = DataDef.record(
  name: 'WidgetInstance',
  members: [
    PalMember(
      id: widgetInstanceIDID,
      name: 'id',
      type: widgetIDDef.asType(),
    ),
    PalMember(
      id: widgetInstanceWidgetID,
      name: 'widget',
      type: widgetDef.asType(),
    ),
    PalMember(
      id: widgetInstanceFieldsID,
      name: 'fields',
      type: MapType(textType, UnionType({datumDef.asType(), anyType})),
    ),
  ],
);

final flutterWidgetDef = InterfaceDef(name: 'FlutterWidget', members: []);

Object defaultInstance(Ctx ctx, Object widget) {
  final defaultFields = widget.recordAccess(widgetDefaultFieldsID) as WidgetDefaultFieldsFn;
  return Dict({
    widgetInstanceIDID: WidgetID.create(),
    widgetInstanceWidgetID: widget,
    widgetInstanceFieldsID: defaultFields(ctx: ctx)
  });
}
