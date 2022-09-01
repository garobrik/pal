import 'package:ctx/ctx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart' hide Dict, Vec;
import 'package:knose/infra_widgets.dart';
import 'package:knose/src/pal2/lang.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'pal_editor.g.dart';

@reader
Widget _testThingy(Ctx ctx) {
  final module = useCursor(coreModule);
  final moduleCtx = useMemoized(
    () => GetCursor.compute(
      (ctx) => Module.load(coreCtx, Ctx.empty, module.read(ctx)),
      ctx: ctx,
    ),
  );
  final expr = useCursor(placeholder);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ReaderWidget(
        ctx: ctx,
        builder: (_, ctx) => ExprEditor(moduleCtx.read(ctx), expr),
      ),
      const Divider(),
      Expanded(
        child: ModuleEditor(
          coreCtx,
          module,
        ),
      ),
    ],
  );
}

@reader
Widget _moduleEditor(BuildContext context, Ctx ctx, Cursor<Object> module) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'module '),
          _inlineTextField(context, ctx, module[Module.nameID].cast<String>()),
          const TextSpan(text: ' {'),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: FocusTraversalGroup(
              policy: HierarchicalOrderTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: module[Module.definitionsID]
                    .cast<Vec>()
                    .values(ctx)
                    .map<Widget>((moduleDef) {
                      return ReaderWidget(
                        ctx: ctx,
                        builder: (_, ctx) {
                          final impl = moduleDef[ModuleDef.implID].read(ctx);
                          if (impl == TypeDef.moduleDefImpl) {
                            final name = moduleDef[ModuleDef.dataID][TypeDef.treeID]
                                    [TypeTree.nameID]
                                .read(ctx);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('type $name {'),
                                Container(
                                  padding: const EdgeInsetsDirectional.only(start: 10),
                                  child: TypeTreeEditor(
                                    ctx.withThisDef(
                                      Type.mk(moduleDef[ModuleDef.dataID][TypeDef.IDID].read(ctx)
                                          as ID),
                                    ),
                                    moduleDef[ModuleDef.dataID][TypeDef.treeID],
                                  ),
                                ),
                                const Text('}'),
                              ],
                            );
                          } else if (impl == InterfaceDef.moduleDefImpl) {
                            final name = moduleDef[ModuleDef.dataID][InterfaceDef.membersID]
                                    [TypeTree.nameID]
                                .read(ctx);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('interface $name {'),
                                Container(
                                  padding: const EdgeInsetsDirectional.only(start: 10),
                                  child: TypeTreeEditor(
                                    ctx,
                                    moduleDef[ModuleDef.dataID][InterfaceDef.membersID],
                                  ),
                                ),
                                const Text('}'),
                              ],
                            );
                          } else if (impl == ImplDef.moduleDefImpl) {
                            final interfaceDef = ctx.getInterface(
                              moduleDef[ModuleDef.dataID][ImplDef.implementedID].read(ctx) as ID,
                            );
                            return Option.cases(
                              Option.mk(InterfaceDef.type, interfaceDef),
                              // Binding.value(
                              //   ctx.getInterface(
                              //     moduleDef[ModuleDef.dataID][ImplDef.implementedID].read(ctx) as ID,
                              //   ),
                              // ),
                              none: () => const Text('unknown interface'),
                              some: (interfaceDef) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'impl of ${TypeTree.name(InterfaceDef.members(interfaceDef))} {'),
                                    Container(
                                      padding: const EdgeInsetsDirectional.only(start: 10),
                                      child: DataTreeEditor(
                                        ctx,
                                        InterfaceDef.members(interfaceDef),
                                        moduleDef[ModuleDef.dataID][ImplDef.membersID],
                                      ),
                                    ),
                                    const Text('}'),
                                  ],
                                );
                              },
                            );
                          } else {
                            throw Exception('unknown ModuleDef impl $impl');
                          }
                        },
                      );
                    })
                    .intersperse(const Divider())
                    .toList(),
              ),
            ),
          ),
        ),
      ),
      const Text('}'),
    ],
  );
}

@reader
Widget _typeTreeEditor(BuildContext context, Ctx ctx, Cursor<Object> typeTree) {
  final tag = typeTree[TypeTree.treeID][UnionTag.tagID].read(ctx);
  if (tag == TypeTree.recordID || tag == TypeTree.unionID) {
    final subTree = typeTree[TypeTree.treeID][UnionTag.valueID].cast<Dict>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in subTree.keys.read(ctx)) ...[
          Text.rich(TextSpan(children: [
            if (subTree[key].whenPresent[TypeTree.treeID][UnionTag.tagID].read(ctx) ==
                TypeTree.unionID)
              const TextSpan(text: 'union '),
            if (subTree[key].whenPresent[TypeTree.treeID][UnionTag.tagID].read(ctx) ==
                TypeTree.recordID)
              const TextSpan(text: 'record '),
            _inlineTextField(
              context,
              ctx,
              subTree[key].whenPresent[TypeTree.nameID].cast<String>(),
            ),
            const TextSpan(text: ':'),
          ])),
          Container(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: TypeTreeEditor(ctx, subTree[key].whenPresent),
          ),
        ]
      ],
    );
  } else if (tag == TypeTree.leafID) {
    return ExprEditor(ctx, typeTree[TypeTree.treeID][UnionTag.valueID]);
  } else {
    throw Exception('unknown type tree union case');
  }
}

@reader
Widget _dataTreeEditor(Ctx ctx, Object typeTree, Cursor<Object> dataTree) {
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
              leaf: (_) => true,
            )) ...[
              Text('${TypeTree.name(entry.value)}:'),
              Container(
                padding: const EdgeInsetsDirectional.only(start: 10),
                child: DataTreeEditor(ctx, entry.value, dataTree[entry.key]),
              ),
            ] else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${TypeTree.name(entry.value)}: '),
                    AlignedWidgetSpan(DataTreeEditor(ctx, entry.value, dataTree[entry.key]))
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
              UnionTag.mk(newTag as ID, TypeTree.instantiate(union[newTag].unwrap!, placeholder)),
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
            child: DataTreeEditor(ctx, union[currentTag].unwrap!, dataTree[UnionTag.valueID]),
          ),
          const Text(')')
        ],
      );
    },
    leaf: (leaf) {
      return ExprEditor(ctx, dataTree);
    },
  );
}

@reader
Widget _exprEditor(BuildContext context, Ctx ctx, Cursor<Object> expr) {
  final impl = expr[Expr.implID];
  final data = expr[Expr.dataID];

  late final Widget child;
  if (impl.read(ctx) == Fn.exprImpl) {
    late final Widget body;
    if (data[Fn.bodyID][UnionTag.tagID].read(ctx) == Fn.dartID) {
      body = const Text('dart implementation', style: TextStyle(fontStyle: FontStyle.italic));
    } else {
      body = ExprEditor(
        ctx.withBinding(Binding.mk(
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
            const TextSpan(text: '('),
            _inlineTextField(context, ctx, data[Fn.argNameID].cast<String>()),
            const TextSpan(text: ': '),
            TextSpan(
                text: TypeTree.name(
              TypeDef.tree(
                ctx.getType(data[Fn.fnTypeID][Fn.argTypeID][Type.IDID].read(ctx) as ID),
              ),
            ).toString()),
            const TextSpan(text: ')'),
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
            const TextSpan(text: ' {'),
          ]),
        ),
        Container(padding: const EdgeInsetsDirectional.only(start: 10), child: body),
        const Text('}'),
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
            style: ButtonStyle(
              padding: MaterialStateProperty.all(EdgeInsetsDirectional.zero),
              minimumSize: MaterialStateProperty.all(Size.zero),
            ),
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
            style: ButtonStyle(
              padding: MaterialStateProperty.all(EdgeInsetsDirectional.zero),
              minimumSize: MaterialStateProperty.all(Size.zero),
            ),
            items: record.keys,
            currentItem: data[RecordAccess.memberID].read(ctx),
            buildItem: (memberID) => Text(TypeTree.name(record[memberID].unwrap!).toString()),
            onItemSelected: (key) => data[RecordAccess.memberID].set(key),
            child: Text(
              TypeTree.name(record[data[RecordAccess.memberID].read(ctx)].unwrap!).toString(),
            ),
          ));
        },
        none: () => const TextSpan(text: 'member', style: TextStyle(fontStyle: FontStyle.italic)),
      ),
    ]));
  } else if (impl.read(ctx) == Var.exprImpl) {
    final varID = data[Var.IDID].read(ctx);
    final binding = ctx.getBinding(varID as ID);
    child = Text(Binding.name(binding));
  } else if (impl.read(ctx) == Literal.exprImpl) {
    child = Text(data[Literal.valueID].read(ctx).toString());
  } else if (impl.read(ctx) == ThisDef.exprImpl) {
    child = const Text('this');
  } else if (impl.read(ctx) == Construct.impl) {
    final typeDef = ctx.getType(data[Construct.dataTypeID][Type.IDID].read(ctx) as ID);

    child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${TypeTree.name(TypeDef.tree(typeDef))}('),
        Container(
          padding: const EdgeInsetsDirectional.only(start: 10),
          child: DataTreeEditor(ctx, TypeDef.tree(typeDef), data[Construct.treeID]),
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
                  for (final binding in ctx.getBindings) Var.mk(Binding.id(binding)),
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
                      child: ReaderWidget(
                        ctx: ctx,
                        builder: (_, ctx) {
                          if (Expr.impl(possibleExpr) == Var.exprImpl) {
                            final binding = ctx.getBinding(Var.id(Expr.data(possibleExpr)));
                            return Text('${Binding.name(binding)}: ${Binding.valueType(binding)}');
                          } else {
                            return Text(
                              TypeTree.name(
                                TypeDef.tree(
                                  ctx.getType(Type.id(Construct.dataType(Expr.data(possibleExpr)))),
                                ),
                              ),
                            );
                          }
                        },
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
  } else if (impl.read(ctx) == List.mkExprImpl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in data[List.mkValuesID].cast<Vec>().values(ctx)) ...[
          ExprEditor(ctx, child),
          const Divider(),
        ]
      ],
    );
  } else {
    throw Exception('unknown expr!! ${expr.read(ctx)}');
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
            // border: Border.all(
            //   color: Focus.of(context).hasPrimaryFocus ? Colors.black : Colors.transparent,
            // ),
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                color: Focus.of(context).hasPrimaryFocus ? Colors.grey : Colors.transparent,
                blurStyle: BlurStyle.outer,
              )
            ],
          ),
          child: child,
        );
      },
    ),
  );
}

InlineSpan _inlineTextField(BuildContext context, Ctx ctx, Cursor<String> text) {
  return AlignedWidgetSpan(
    IntrinsicWidth(
      child: BoundTextFormField(
        text,
        ctx: ctx,
        decoration: const InputDecoration(
          contentPadding: EdgeInsetsDirectional.all(2),
        ),
        style: Theme.of(context).textTheme.bodyText2,
      ),
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

class HierarchicalOrderTraversalPolicy extends FocusTraversalPolicy
    with DirectionalFocusTraversalPolicyMixin {
  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    final sorted = [...descendants];
    mergeSort(sorted, compare: (FocusNode node1, FocusNode node2) {
      if (node1.ancestors.contains(node2)) return 1;
      if (node2.ancestors.contains(node1)) return -1;
      return 0;
    });
    return sorted;
  }
}
