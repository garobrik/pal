import 'dart:math';

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
      (ctx) => Module.load(Ctx.empty, module.read(ctx)),
      ctx: ctx,
    ),
  );
  final expr = useCursor(placeholder);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ReaderWidget(
        ctx: ctx,
        builder: (_, ctx) => Option.cases(
          moduleCtx.read(ctx),
          some: (moduleCtx) => ExprEditor(moduleCtx as Ctx, expr),
          none: () => const Text('module load error!'),
        ),
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
Widget _moduleEditor(Ctx ctx, Cursor<Object> module) {
  final definitions = module[Module.definitionsID][List.itemsID].cast<Vec>();
  return FocusTraversalGroup(
    policy: HierarchicalOrderTraversalPolicy(),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'module '),
            _inlineTextField(ctx, module[Module.nameID].cast<String>()),
            const TextSpan(text: ' {'),
          ]),
        ),
        Expanded(
          child: InsetChild(
            ListView.separated(
              itemCount: definitions.length.read(ctx),
              shrinkWrap: true,
              separatorBuilder: (context, index) => ReaderWidget(
                ctx: ctx,
                builder: (context, ctx) {
                  final isOpen = useCursor(false);
                  final leftProportion = useCursor(0.0);
                  return MouseRegion(
                    onEnter: (hoverEvent) {
                      isOpen.set(true);
                      leftProportion.set(hoverEvent.localPosition.dx);
                    },
                    onHover: (hoverEvent) {
                      isOpen.set(true);
                      leftProportion.set(hoverEvent.localPosition.dx);
                    },
                    onExit: (_) => isOpen.set(false),
                    child: Stack(
                      alignment: AlignmentDirectional.center,
                      fit: StackFit.passthrough,
                      children: [
                        const Divider(height: 20),
                        if (isOpen.read(ctx))
                          Positioned(
                            left: max(0, leftProportion.read(ctx) - 50),
                            child: Material(
                              child: TextButton.icon(
                                onPressed: () => definitions.insert(
                                  index + 1,
                                  TypeDef.mkDef(TypeDef.unit('unnamed')),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Add definition'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              itemBuilder: (context, index) {
                final moduleDef = definitions[index];
                final dataType = moduleDef[ModuleDef.implID][ModuleDef.dataTypeID].read(ctx);
                late final Cursor<Object> id;
                if (dataType == TypeDef.type) {
                  id = moduleDef[ModuleDef.dataID][TypeDef.IDID];
                } else if (dataType == InterfaceDef.type) {
                  id = moduleDef[ModuleDef.dataID][InterfaceDef.IDID];
                } else if (dataType == ImplDef.type) {
                  id = moduleDef[ModuleDef.dataID][ImplDef.IDID];
                } else {
                  throw Exception('unknown moduledef impl');
                }
                return ReaderWidget(
                  key: ValueKey(id.read(ctx)),
                  ctx: ctx,
                  builder: (_, ctx) {
                    final dataType = moduleDef[ModuleDef.implID][ModuleDef.dataTypeID].read(ctx);
                    if (dataType == TypeDef.type) {
                      final name = moduleDef[ModuleDef.dataID][TypeDef.treeID][TypeTree.nameID];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(TextSpan(children: [
                            const TextSpan(text: 'type '),
                            _inlineTextField(ctx, name.cast<String>()),
                            const TextSpan(text: ' {'),
                          ])),
                          InsetChild(
                            TypeTreeEditor(ctx, moduleDef[ModuleDef.dataID][TypeDef.treeID]),
                          ),
                          const Text('}'),
                        ],
                      );
                    } else if (dataType == InterfaceDef.type) {
                      final name =
                          moduleDef[ModuleDef.dataID][InterfaceDef.treeID][TypeTree.nameID];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(TextSpan(children: [
                            const TextSpan(text: 'interface '),
                            _inlineTextField(ctx, name.cast<String>()),
                            const TextSpan(text: ' {'),
                          ])),
                          InsetChild(
                            TypeTreeEditor(
                              ctx,
                              moduleDef[ModuleDef.dataID][InterfaceDef.treeID],
                            ),
                          ),
                          const Text('}'),
                        ],
                      );
                    } else if (dataType == ImplDef.type) {
                      final interfaceDef = ctx.getInterface(
                        moduleDef[ModuleDef.dataID][ImplDef.implementedID].read(ctx) as ID,
                      );
                      return Option.cases(
                        Option.mk(interfaceDef),
                        none: () => const Text('unknown interface'),
                        some: (interfaceDef) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('impl of ${TypeTree.name(InterfaceDef.tree(interfaceDef))} {'),
                              InsetChild(
                                DataTreeEditor(
                                  ctx,
                                  InterfaceDef.tree(interfaceDef),
                                  moduleDef[ModuleDef.dataID][ImplDef.membersID],
                                ),
                              ),
                              const Text('}'),
                            ],
                          );
                        },
                      );
                    } else {
                      throw Exception('unknown ModuleDef type $dataType');
                    }
                  },
                );
              },
            ),
          ),
        ),
        const Text('}'),
      ],
    ),
  );
}

@reader
Widget _typeTreeEditor(Ctx ctx, Cursor<Object> typeTree) {
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
            _inlineTextField(ctx, subTree[key].whenPresent[TypeTree.nameID].cast<String>()),
            const TextSpan(text: ':'),
          ])),
          InsetChild(
            TypeTreeEditor(ctx, subTree[key].whenPresent),
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
              InsetChild(
                DataTreeEditor(ctx, entry.value, dataTree[entry.key]),
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
          InsetChild(
            DataTreeEditor(ctx, union[currentTag].unwrap!, dataTree[UnionTag.valueID]),
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
  final placeholderFocusNode = useFocusNode();
  final wrapperFocusNode = useFocusNode();
  final dataType = expr[Expr.implID][Expr.dataTypeID].read(ctx);
  final data = expr[Expr.dataID];

  late final Widget child;
  if (dataType == Type.mk(Fn.typeDefID)) {
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
            _inlineTextField(ctx, data[Fn.argNameID].cast<String>()),
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
        InsetChild(body),
        const Text('}'),
      ],
    );
  } else if (dataType == TypeDef.asType(FnApp.typeDef)) {
    if (data[FnApp.fnID][Expr.implID][Expr.dataTypeID].read(ctx) == TypeDef.asType(Var.typeDef)) {
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
          InsetChild(
            Column(
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
  } else if (dataType == TypeDef.asType(RecordAccess.typeDef)) {
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
  } else if (dataType == TypeDef.asType(Var.typeDef)) {
    final varID = data[Var.IDID].read(ctx);
    child = Option.cases(
      ctx.getBinding(varID as ID),
      some: (binding) => Text(Binding.name(binding)),
      none: () => Text(
        'unknown var $varID',
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
    );
  } else if (dataType == TypeDef.asType(Literal.typeDef)) {
    child = Text(data[Literal.valueID].read(ctx).toString());
  } else if (dataType == Construct.type) {
    final typeDef = ctx.getType(data[Construct.dataTypeID][Type.IDID].read(ctx) as ID);

    child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${TypeTree.name(TypeDef.tree(typeDef))}('),
        InsetChild(
          DataTreeEditor(ctx, TypeDef.tree(typeDef), data[Construct.treeID]),
        ),
        const Text(')'),
      ],
    );
  } else if (dataType == TypeDef.asType(Placeholder.typeDef)) {
    return ReaderWidget(
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
              return Container(
                constraints: const BoxConstraints(maxHeight: 500),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...ctx.getBindings.expand((binding) {
                        return Option.cases(
                          Binding.value(ctx, binding),
                          none: () => [],
                          some: (value) {
                            return [
                              if (Binding.valueType(ctx, binding) == TypeDef.type)
                                TextButton(
                                  onPressed: () {
                                    expr.set(Construct.mk(
                                      TypeDef.asType(value),
                                      TypeTree.instantiate(TypeDef.tree(value), placeholder),
                                    ));
                                    wrapperFocusNode.requestFocus();
                                  },
                                  child: Text('${TypeTree.name(TypeDef.tree(value))}.mk(...)'),
                                )
                              else
                                TextButton(
                                  onPressed: () {
                                    expr.set(Var.mk(Binding.id(binding)));
                                    wrapperFocusNode.requestFocus();
                                  },
                                  child: Text(
                                    '${Binding.name(binding)}: ${Binding.valueType(ctx, binding)}',
                                  ),
                                )
                            ];
                          },
                        );
                      }),
                    ],
                  ),
                ),
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
                  wrapperFocusNode.requestFocus();
                }

                if (currentText.startsWith("'") && currentText.endsWith("'")) {
                  final tryString = currentText.substring(1, currentText.length - 1);
                  if (!tryString.contains("'")) {
                    expr.set(Literal.mk(text, tryString));
                    wrapperFocusNode.requestFocus();
                  }
                }

                return KeyEventResult.handled;
              }

              return KeyEventResult.ignored;
            },
            child: BoundTextFormField(
              inputText,
              ctx: ctx,
              focusNode: placeholderFocusNode,
            ),
          ),
        );
      },
    );
  } else if (dataType == TypeDef.asType(List.exprTypeDef)) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in data[List.mkValuesID][List.itemsID].cast<Vec>().values(ctx)) ...[
          ExprEditor(ctx, child),
          const Divider(),
        ]
      ],
    );
  } else {
    throw Exception('unknown expr!! ${expr.read(ctx)}');
  }

  return Shortcuts.manager(
    manager: NonTextEditingShortcutManager(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.backspace): VoidCallbackIntent(() {
          expr.set(placeholder);
          placeholderFocusNode.requestFocus();
        }),
        const SingleActivator(LogicalKeyboardKey.keyJ): VoidCallbackIntent(() {
          var child = wrapperFocusNode;
          for (final parent in wrapperFocusNode.ancestors) {
            final iterator = parent.hierarchicalTraversableDescendants.iterator;
            while (iterator.moveNext()) {
              if (iterator.current == child) break;
            }
            while (iterator.moveNext()) {
              if (!iterator.current.ancestors.contains(child)) {
                iterator.current.requestFocus();
                return;
              }
            }
          }
        }),
        const SingleActivator(LogicalKeyboardKey.keyK): VoidCallbackIntent(() {
          final nearestAncestor = wrapperFocusNode.ancestors.firstWhere(
            (ancestor) => ancestor.canRequestFocus && !ancestor.skipTraversal,
            orElse: () => wrapperFocusNode,
          );

          final iterator =
              [...nearestAncestor.hierarchicalTraversableDescendants].reversed.iterator;
          while (iterator.moveNext()) {
            if (iterator.current == wrapperFocusNode) {
              break;
            }
          }
          while (iterator.moveNext()) {
            if (!iterator.current.ancestors
                .takeWhile((ancestor) => ancestor != nearestAncestor)
                .any((ancestor) => ancestor.canRequestFocus && !ancestor.skipTraversal)) {
              iterator.current.requestFocus();
              return;
            }
          }
          nearestAncestor.requestFocus();
        }),
        const SingleActivator(LogicalKeyboardKey.keyH): VoidCallbackIntent(() {
          for (final ancestor in wrapperFocusNode.ancestors) {
            if (!ancestor.skipTraversal && ancestor.canRequestFocus) {
              ancestor.requestFocus();
              return;
            }
          }
        }),
        const SingleActivator(LogicalKeyboardKey.keyL): VoidCallbackIntent(() {
          if (wrapperFocusNode.traversalDescendants.isNotEmpty) {
            wrapperFocusNode.traversalDescendants.first.requestFocus();
          }
        }),
      },
    ),
    child: Focus(
      focusNode: wrapperFocusNode,
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
    ),
  );
}

class NonTextEditingShortcutManager extends ShortcutManager {
  NonTextEditingShortcutManager({required super.shortcuts});

  @override
  KeyEventResult handleKeypress(BuildContext context, RawKeyEvent event) {
    if (primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null) {
      return KeyEventResult.ignored;
    }
    return super.handleKeypress(context, event);
  }
}

@reader
Widget _insetChild(Widget child) {
  return Container(
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Colors.black12)),
    ),
    padding: const EdgeInsetsDirectional.only(start: 10),
    child: child,
  );
}

InlineSpan _inlineTextField(Ctx ctx, Cursor<String> text) {
  return AlignedWidgetSpan(
    IntrinsicWidth(
      child: Builder(
        builder: (context) => BoundTextFormField(
          text,
          ctx: ctx,
          decoration: const InputDecoration(
            contentPadding: EdgeInsetsDirectional.all(2),
          ),
          style: Theme.of(context).textTheme.bodyText2,
        ),
      ),
    ),
  );
}

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
      return ReadingOrderTraversalPolicy().sortDescendants([node1, node2], node1).first == node1
          ? -1
          : 1;
    });
    return sorted;
  }
}

extension HierarchicalDescendants on FocusNode {
  Iterable<FocusNode> get hierarchicalTraversableDescendants sync* {
    if (!descendantsAreFocusable) return;
    for (final child in children) {
      if (child.canRequestFocus && !child.skipTraversal) yield child;
      yield* child.hierarchicalTraversableDescendants;
    }
  }
}
