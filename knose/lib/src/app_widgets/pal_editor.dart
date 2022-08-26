import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart' hide Dict;
import 'package:knose/infra_widgets.dart';
import 'package:knose/src/pal2/lang.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'pal_editor.g.dart';

@reader
Widget _exprEditor(Ctx ctx, Cursor<Object> expr) {
  final impl = expr[Expr.implID];
  final data = expr[Expr.dataID];

  late final Widget child;
  if (impl.read(ctx) == Fn.exprImpl) {
    late final Widget body;
    if (data[Fn.bodyID][UnionTag.tagID].read(ctx) == Fn.dartID) {
      body = const Text('dart implementation', style: TextStyle(fontStyle: FontStyle.italic));
    } else {
      body = ExprEditor(
        ctx.withBinding(Binding(
          id: data[Fn.argIDID].read(ctx) as ID,
          type: data[Fn.fnTypeID][Fn.argTypeID].read(ctx),
          name: data[Fn.argNameID].read(ctx) as String,
        )),
        data[Fn.bodyID][UnionTag.valueID],
      );
    }

    child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            const WidgetSpan(
              alignment: PlaceholderAlignment.bottom,
              baseline: TextBaseline.ideographic,
              child: Icon(
                Icons.arrow_right_alt,
                size: 16,
              ),
            ),
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
    if (data[FnApp.fnID][Expr.implID].read(ctx) == Var.exprImpl) {
      child = Text.rich(TextSpan(children: [
        AlignedWidgetSpan(ExprEditor(ctx, data[FnApp.fnID])),
        const TextSpan(text: '('),
        AlignedWidgetSpan(ExprEditor(ctx, data[FnApp.argID])),
        const TextSpan(text: ')'),
      ]));
    } else {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('apply('),
          Container(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExprEditor(ctx, data[FnApp.fnID]),
                ExprEditor(ctx, data[FnApp.argID]),
              ],
            ),
          ),
          const Text(')'),
        ],
      );
    }
  } else if (impl.read(ctx) == InterfaceAccess.exprImpl) {
    final targetType = typeCheck(ctx, data[InterfaceAccess.targetID].read(ctx));
    child = Text.rich(TextSpan(children: [
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
    child = Text.rich(TextSpan(children: [
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
    child = Text(binding.name);
  } else if (impl.read(ctx) == Literal.exprImpl) {
    child = Text(data[Literal.valueID].read(ctx).toString());
  } else if (impl.read(ctx) == ThisDef.exprImpl) {
    child = const Text('this');
  } else if (impl.read(ctx) == Construct.impl) {
    final typeDef = ctx.getType(data[Construct.dataTypeID][Type.IDID].read(ctx) as ID);

    Widget createChild(Object typeTree, Cursor<Object> dataTree) {
      return TypeTree.treeCases(
        typeTree,
        record: (record) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${TypeTree.name(entry.value)}:'),
                        AlignedWidgetSpan(createChild(entry.value, dataTree[entry.key]))
                      ],
                    ),
                  ),
            ],
          );
        },
        union: (union) {
          final currentTag = dataTree[UnionTag.tagID].read(ctx);
          final dropdown = IntrinsicWidth(
            child: DropdownMenu<Object>(
              style: ButtonStyle(
                padding: MaterialStateProperty.all(EdgeInsetsDirectional.zero),
                minimumSize: MaterialStateProperty.all(Size.zero),
              ),
              items: [...union.keys],
              currentItem: currentTag,
              buildItem: (tag) => Text(TypeTree.name(union[tag].unwrap!).toString()),
              onItemSelected: (newTag) {
                dataTree.set(
                  UnionTag.mk(newTag as ID, TypeTree.instantiate(union[newTag].unwrap!, data)),
                );
              },
              child: Row(children: [
                Text(TypeTree.name(union[currentTag].unwrap!)),
                // const Icon(Icons.arrow_drop_down)
              ]),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [AlignedWidgetSpan(dropdown), const TextSpan(text: '(')]),
              ),
              Container(
                padding: const EdgeInsetsDirectional.only(start: 10),
                child: createChild(union[currentTag].unwrap!, dataTree[UnionTag.valueID]),
              ),
              const Text(')')
            ],
          );
        },
        leaf: (leaf) {
          return Text.rich(TextSpan(children: [
            // TextSpan(text: '${TypeTree.name(typeTree)}: '),
            AlignedWidgetSpan(ExprEditor(ctx, dataTree)),
          ]));
        },
      );
    }

    child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${TypeTree.name(TypeDef.tree(typeDef))}('),
        Container(
          padding: const EdgeInsetsDirectional.only(start: 10),
          child: createChild(TypeDef.tree(typeDef), data[Construct.treeID]),
        ),
        const Text(')'),
      ],
    );
  } else if (impl.read(ctx) == Placeholder.exprImpl) {
    child = ReaderWidget(
      ctx: ctx,
      builder: (_, ctx) {
        final inputText = useCursor('');
        final isOpen = useCursor(false);
        useEffect(
          () => inputText.listen((old, nu, diff) {
            if (old.isEmpty && nu.isNotEmpty) isOpen.set(true);
            if (old.isNotEmpty && nu.isEmpty) isOpen.set(false);
          }),
        );
        return DeferredDropdown(
          isOpen: isOpen,
          dropdown: ReaderWidget(
            ctx: ctx,
            builder: (_, ctx) {
              final possibleExprs = useMemoized(
                () => [
                  for (final binding in ctx.getBindings) Var.mk(binding.id),
                  for (final typeDef in ctx.getTypes)
                    Construct.mk(
                      TypeDef.asType(typeDef),
                      TypeTree.instantiate(TypeDef.tree(typeDef), placeholder),
                    ),
                ],
                [ctx],
              );
              return Column(
                children: [
                  for (final possibleExpr in possibleExprs)
                    TextButton(
                      onPressed: () => expr.set(possibleExpr),
                      child: Text(
                        Expr.impl(possibleExpr) == Var.exprImpl
                            ? ctx.getBinding(Var.id(Expr.data(possibleExpr))).name
                            : TypeTree.name(
                                TypeDef.tree(
                                  ctx.getType(Type.id(Construct.dataType(Expr.data(possibleExpr)))),
                                ),
                              ),
                      ),
                    ),
                ],
              );
            },
          ),
          child: Focus(
            skipTraversal: false,
            onKeyEvent: (node, event) {
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                final currentText = inputText.read(Ctx.empty);
                final tryNum = num.tryParse(currentText);
                if (tryNum != null) {
                  expr.set(Literal.mk(number, tryNum));
                }

                final tryString = currentText.substring(1, currentText.length - 1);
                if (currentText.startsWith("'") &&
                    currentText.endsWith("'") &&
                    !tryString.contains("'")) {
                  expr.set(Literal.mk(text, tryString));
                }

                return KeyEventResult.handled;
              }

              return KeyEventResult.ignored;
            },
            child: BoundTextFormField(inputText, ctx: ctx),
          ),
        );
      },
    );
  } else {
    throw Exception('unknown expr!!');
  }

  return Focus(
    onKeyEvent: (node, event) {
      if (node.hasPrimaryFocus && event.logicalKey == LogicalKeyboardKey.backspace) {
        expr.set(placeholder);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: ReaderWidget(
      ctx: ctx,
      builder: (context, ctx) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Focus.of(context).hasPrimaryFocus ? Colors.black : Colors.transparent,
            ),
          ),
          child: child,
        );
      },
    ),
  );
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
