import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/pal.dart';
import 'dart:core' as dart;
import 'dart:core';

final DB coreDB = () {
  final db = Cursor(const DB());
  for (final interface in _interfaceTypes) {
    db.update(interface.id, interface);
  }
  for (final impl in _implementations) {
    db.update(impl.id, impl);
  }

  return db.read(Ctx.empty);
}();

final _interfaceTypes = <InterfaceDef>[
  palIDDef,
  cursorDef,
];
final _implementations = <Impl>[];

final memberIDDef = InterfaceDef(name: 'MemberID', members: []);

final optionTypeID = MemberID();
final optionValueID = MemberID();
final optionSomeID = MemberID();
final optionNoneID = MemberID();
final optionDef = DataDef(
  tree: RecordNode('Option', {
    optionTypeID: const LeafNode('T', type),
    optionValueID: UnionNode('value', {
      optionSomeID: LeafNode('some', RecordAccess(optionTypeID)),
      optionNoneID: const LeafNode('none', unit),
    }),
  }),
);

Type optionType(Type type) => optionDef.asType(assignments: {optionTypeID: type});
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
    Member(name: 'namespace', type: text),
    Member(name: 'id', type: text),
  ],
);

Type cursorType(Type type) => cursorDef.asType({cursorTypeID: type});
final cursorTypeID = MemberID();
final cursorDef = InterfaceDef(
  name: 'Cursor',
  members: [Member(id: cursorTypeID, name: 'type', type: type)],
);

final datumDef = InterfaceDef(
  name: 'Datum',
  members: [],
);
