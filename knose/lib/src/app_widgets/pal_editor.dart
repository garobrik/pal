import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart' hide Dict;
import 'package:knose/infra_widgets.dart';
import 'package:knose/src/pal2/lang.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'pal_editor.g.dart';

@reader
Widget exprEditor(Ctx ctx, Cursor<Object> expr) {
  final impl = expr[Expr.implID];
  final data = expr[Expr.dataID];

  if (impl.read(ctx) == Fn.exprImpl) {
    late final Widget body;
    if (data[Fn.bodyID][UnionTag.tagID].read(ctx) == Fn.dartID) {
      body = const Text('dart implementation', style: TextStyle(fontStyle: FontStyle.italic));
    } else {
      body = ExprEditor(
        ctx.withBinding(
          data[Fn.argIDID].read(ctx) as ID,
          Binding(
            type: data[Fn.fnTypeID][Fn.argTypeID].read(ctx),
          ),
        ),
        data[Fn.bodyID][UnionTag.valueID],
      );
    }

    return Column(
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: TypeTree.name(
                TypeDef.tree(
                  ctx.getType(data[Fn.fnTypeID][Fn.argTypeID][Type.IDID].read(ctx) as ID),
                ),
              ).toString(),
            ),
            const TextSpan(text: ' -> '),
            TextSpan(
              text: TypeTree.name(
                TypeDef.tree(
                  ctx.getType(data[Fn.fnTypeID][Fn.argTypeID][Type.IDID].read(ctx) as ID),
                ),
              ).toString(),
            ),
          ]),
        ),
        const Divider(),
        body,
      ],
    );
  } else if (impl.read(ctx) == FnApp.exprImpl) {
    return Text.rich(TextSpan(children: [
      AlignedWidgetSpan(ExprEditor(ctx, data[FnApp.fnID])),
      const TextSpan(text: '('),
      AlignedWidgetSpan(ExprEditor(ctx, data[FnApp.argID])),
      const TextSpan(text: ')'),
    ]));
  } else if (impl.read(ctx) == InterfaceAccess.exprImpl) {
    final targetType = typeCheck(ctx, data[InterfaceAccess.targetID].read(ctx));
    return Text.rich(TextSpan(children: [
      AlignedWidgetSpan(ExprEditor(ctx, data[InterfaceAccess.targetID])),
      const TextSpan(text: '.'),
      Option.cases(
        targetType,
        some: (type) {
          final interfaceImplemented = Type.memberEquals(type, [Impl.IDID]);
          final interfaceDef = ctx.getInterface(interfaceImplemented as ID);
          final record = TypeTree.treeCases(
            InterfaceDef.members(interfaceDef),
            union: (_) => throw Exception(),
            leaf: (_) => throw Exception(),
            record: (record) => record,
          );
          return AlignedWidgetSpan(DropdownMenu<Object>(
            items: record.keys,
            currentItem: data[InterfaceAccess.memberID].read(ctx),
            buildItem: (memberID) => Text(TypeTree.name(record[memberID].unwrap!).toString()),
            onItemSelected: (key) => data[InterfaceAccess.memberID].set(key),
            child: Text(
              TypeTree.name(record[data[InterfaceAccess.memberID].read(ctx)].unwrap!).toString(),
            ),
          ));
        },
        none: () => const TextSpan(text: 'member', style: TextStyle(fontStyle: FontStyle.italic)),
      ),
    ]));
  } else if (impl.read(ctx) == RecordAccess.exprImpl) {
    final targetType = typeCheck(ctx, data[RecordAccess.targetID].read(ctx));
    return Text.rich(TextSpan(children: [
      AlignedWidgetSpan(ExprEditor(ctx, data[RecordAccess.targetID])),
      const TextSpan(text: '.'),
      Option.cases(
        targetType,
        some: (type) {
          final typeDef = ctx.getType(Type.id(type));
          final record = TypeTree.treeCases(
            TypeDef.tree(typeDef),
            union: (_) => throw Exception(),
            leaf: (_) => throw Exception(),
            record: (record) => record,
          );
          return AlignedWidgetSpan(DropdownMenu<Object>(
            items: record.keys,
            currentItem: data[InterfaceAccess.memberID].read(ctx),
            buildItem: (memberID) => Text(TypeTree.name(record[memberID].unwrap!).toString()),
            onItemSelected: (key) => data[InterfaceAccess.memberID].set(key),
            child: Text(
              TypeTree.name(record[data[InterfaceAccess.memberID].read(ctx)].unwrap!).toString(),
            ),
          ));
        },
        none: () => const TextSpan(text: 'member', style: TextStyle(fontStyle: FontStyle.italic)),
      ),
    ]));
  } else if (impl.read(ctx) == Var.exprImpl) {
    final varID = data[Var.IDID].read(ctx);
    final binding = ctx.getBinding(varID as ID);
    return Text(binding.name);
  } else if (impl.read(ctx) == Literal.exprImpl) {
    return Text(data[Literal.valueID].read(ctx).toString());
  } else if (impl.read(ctx) == ThisDef.exprImpl) {
    return const Text('this');
  } else if (impl.read(ctx) == Construct.impl) {
    final typeDef = ctx.getType(data[Construct.dataTypeID][Type.IDID].read(ctx) as ID);

    Widget createChild(Object typeTree, Cursor<Object> dataTree) {
      return TypeTree.treeCases(
        typeTree,
        record: (record) {
          return Column(
            children: [
              for (final entry in record.entries)
                if (TypeTree.treeCases(
                  entry.value,
                  record: (_) => true,
                  union: (union) => true,
                  leaf: (_) => false,
                )) ...[
                  Text('${TypeTree.name(entry.value)}:'),
                  Container(
                    padding: const EdgeInsetsDirectional.only(start: 10),
                    child: createChild(entry.value, dataTree[entry.key]),
                  ),
                ] else
                  Text.rich(TextSpan(children: [TextSpan(text: '${TypeTree.name(entry.value)}:')])),
            ],
          );
        },
        union: (union) {
          final currentTag = dataTree[UnionTag.tagID];
          final dropdown = DropdownMenu<Object>(
            items: [...union.keys],
            currentItem: currentTag,
            buildItem: (tag) => Text(TypeTree.name(union[tag]).toString()),
            onItemSelected: (newTag) {},
            child: Row(children: [
              Text('${TypeTree.name(union[currentTag])}'),
              const Icon(Icons.arrow_drop_down)
            ]),
          );
          return Column(children: [
            Text.rich(TextSpan(children: [AlignedWidgetSpan(dropdown), const TextSpan(text: '(')])),
            Container(
              padding: const EdgeInsetsDirectional.only(start: 10),
              child: createChild(union[currentTag], dataTree[UnionTag.valueID]),
            ),
            const Text(')')
          ]);
        },
        leaf: (leaf) {
          return Text.rich(TextSpan(children: [
            TextSpan(text: '${TypeTree.name(leaf)}: '),
            AlignedWidgetSpan(ExprEditor(ctx, dataTree)),
          ]));
        },
      );
    }

    return createChild(TypeDef.tree(typeDef), data[Construct.treeID]);
  } else {
    throw Exception('unknown expr!!');
  }
}

// @reader
// Widget dataEditor(Ctx ctx, Object type, Cursor<Object> data) {
//   final implID = expr[Expr.implID][Impl.IDID];
//   final data = expr[Expr.dataID];
//   final dataType = (ImplDef.members(ctx.getImpl(implID.read(ctx) as ID)) as Dict)[Expr.dataTypeID];
//   final dataTypeDef = ctx.getType(Type.id(dataType));

//   Widget createChild(Object typeTree, Cursor<Object> data) {
//     return TypeTree.treeCases(
//       typeTree,
//       record: (record) {
//         return Column(
//           children: [
//             for (final entry in record.entries)
//               if (TypeTree.treeCases(
//                 entry.value,
//                 record: (_) => true,
//                 union: (union) => true,
//                 leaf: (_) => false,
//               )) ...[
//                 Text('${TypeTree.name(entry.value)}:'),
//                 Container(
//                   padding: const EdgeInsetsDirectional.only(start: 10),
//                   child: createChild(entry.value, data[entry.key]),
//                 ),
//               ]
//           ],
//         );
//       },
//       union: (union) {
//         final currentTag = data[UnionTag.tagID];
//         final dropdown = DropdownMenu<Object>(
//           items: [...union.keys],
//           currentItem: currentTag,
//           buildItem: (tag) => Text(TypeTree.name(union[tag]).toString()),
//           onItemSelected: (newTag) {},
//           child: Row(children: [
//             Text('${TypeTree.name(union[currentTag])}'),
//             const Icon(Icons.arrow_drop_down)
//           ]),
//         );
//         return Column(children: [
//           Text.rich(TextSpan(children: [AlignedWidgetSpan(dropdown), const TextSpan(text: '(')])),
//           Container(
//             padding: const EdgeInsetsDirectional.only(start: 10),
//             child: createChild(union[currentTag], data[UnionTag.valueID]),
//           ),
//           const Text(')')
//         ]);
//       },
//       leaf: (leaf) {
//         return
//       },
//     );
//   }

//   return createChild(TypeDef.tree(dataTypeDef), data);
// }

// @reader
// Widget valueEditor(Ctx ctx, Object type, Cursor<Object> value) {}

extension _PalAccess on Cursor<Object> {
  Cursor<Object> operator [](Object id) => this.cast<Dict>()[id].whenPresent;
}
