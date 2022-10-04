import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart' hide Dict, Vec;
import 'package:knose/infra_widgets.dart';
import 'package:knose/src/pal2/lang.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/src/pal2/print.dart';

part 'pal_editor.g.dart';

abstract class PalCursor {
  static final dataTypeID = ID('dataType');
  static final cursorID = ID('cursor');

  static final defID = ID('Cursor');
  static final def = TypeDef.record(
    'Cursor',
    {
      dataTypeID: Literal.mk(Type.type, Type.type),
      cursorID: Literal.mk(Type.type, unit),
    },
    id: defID,
    comptime: [dataTypeID],
  );

  static Object type(Object type) => Type.mk(defID, properties: [
        MemberHas.mkEquals([dataTypeID], Type.type, type)
      ]);

  static Object typeExpr(Object type) => Type.mkExpr(defID, properties: [
        MemberHas.mkEqualsExpr([dataTypeID], Literal.mk(Type.type, Type.type), type)
      ]);

  static Object mk(Cursor<Object> cursor) => Dict({cursorID: cursor});

  static Cursor<Object> cursor(Object palCursor) =>
      (palCursor as Dict)[cursorID].unwrap! as Cursor<Object>;
}

final palWidgetDef = TypeDef.unit('Widget');
final palWidget = TypeDef.asType(palWidgetDef);

abstract class Editable {
  static final dataTypeID = ID('dataType');
  static final editorID = ID('editor');
  static final editorArgID = ID('editorArg');
  static final interfaceDef = InterfaceDef.record('Editable', {
    dataTypeID: TypeTree.mk('dataType', Literal.mk(Type.type, Type.type)),
    editorID: TypeTree.mk(
      'editor',
      Fn.typeExpr(
        argID: editorArgID,
        argType: PalCursor.typeExpr(Var.mk(dataTypeID)),
        returnType: Literal.mk(Type.type, palWidget),
      ),
    ),
  });

  static Object mkImpl({
    required Object dataType,
    required Object Function(Ctx, Cursor<Object>) editor,
  }) =>
      ImplDef.mkDef(ImplDef.mk(
        implemented: InterfaceDef.id(interfaceDef),
        definition: Dict({
          dataTypeID: Literal.mk(Type.type, dataType),
          editorID: FnExpr.dart(
            argID: editorArgID,
            argName: 'editorArg',
            argType: Literal.mk(Type.type, PalCursor.type(dataType)),
            returnType: Literal.mk(Type.type, palWidget),
            body: (ctx, cursor) => editor(ctx, PalCursor.cursor(cursor)),
          ),
        }),
      ));

  static Object mkParameterizedImpl({
    required Object argType,
    required Object Function(Object) dataType,
    required Object Function(Ctx, Object, Object) editor,
  }) =>
      ImplDef.mkDef(ImplDef.mkDart(
        implemented: InterfaceDef.id(interfaceDef),
        argType: argType,
        returnType: (typeArgExpr) => InterfaceDef.implTypeExpr(interfaceDef, [
          MemberHas.mkEqualsExpr(
            [dataTypeID],
            Literal.mk(Type.type, Type.type),
            dataType(typeArgExpr),
          )
        ]),
        definition: (ctx, typeArgValue) {
          final dataTypeValue = eval(
            ctx,
            FnApp.mk(
              FnExpr.from(
                argName: 'typeArg',
                argType: Literal.mk(Type.type, Type.type),
                returnType: (_) => Literal.mk(Type.type, Type.type),
                body: (arg) => dataType(arg),
              ),
              Literal.mk(Type.type, typeArgValue),
            ),
          );
          return Dict({
            dataTypeID: dataTypeValue,
            editorID: eval(
              ctx,
              FnExpr.dart(
                argID: editorArgID,
                argName: 'data',
                argType: Literal.mk(Type.type, PalCursor.type(dataTypeValue)),
                returnType: Literal.mk(Type.type, palWidget),
                body: (ctx, data) => editor(ctx, dataTypeValue, data),
              ),
            ),
          });
        },
      ));
}

final editorFn = Var.mk(ID('editor'));
final editorArgsDataTypeID = ID('dataType');
final editorArgsCursorID = ID('cursor');
final editorArgsDef = TypeDef.record('EditorArgs', {
  editorArgsDataTypeID: Literal.mk(Type.type, Type.type),
  editorArgsCursorID: PalCursor.typeExpr(Var.mk(editorArgsDataTypeID)),
});

final palUIModule = Module.mk(
  name: 'PalUI',
  definitions: [
    TypeDef.mkDef(PalCursor.def),
    TypeDef.mkDef(palWidgetDef),
    InterfaceDef.mkDef(Editable.interfaceDef),
    TypeDef.mkDef(editorArgsDef),
    ValueDef.mk(
      id: Var.id(Expr.data(editorFn)),
      name: 'editor',
      value: FnExpr.dart(
        argName: 'editable',
        argType: Literal.mk(Type.type, TypeDef.asType(editorArgsDef)),
        returnType: Literal.mk(Type.type, palWidget),
        body: (ctx, arg) {
          final impl = Option.unwrap(
            dispatch(
              ctx,
              InterfaceDef.id(Editable.interfaceDef),
              InterfaceDef.implType(Editable.interfaceDef, [
                MemberHas.mkEquals(
                  [Editable.dataTypeID],
                  Type.type,
                  (arg as Dict)[editorArgsDataTypeID].unwrap!,
                )
              ]),
            ),
          );

          final cursorType = PalCursor.type((impl as Dict)[Editable.dataTypeID].unwrap!);
          return ReaderWidget(
            ctx: ctx,
            builder: (_, ctx) => eval(
              ctx,
              FnApp.mk(
                Literal.mk(
                  Fn.type(
                    argID: Editable.editorArgID,
                    argType: cursorType,
                    returnType: Literal.mk(Type.type, palWidget),
                  ),
                  impl[Editable.editorID].unwrap!,
                ),
                Literal.mk(cursorType, arg[editorArgsCursorID].unwrap!),
              ),
            ) as Widget,
          );
        },
      ),
    ),
    Editable.mkImpl(
      dataType: Module.type,
      editor: (ctx, module) {
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
                    itemBuilder: (_, index) {
                      final moduleDef = definitions[index];
                      final dataType = moduleDef[ModuleDef.implID][ModuleDef.dataTypeID].read(ctx);
                      late final Cursor<Object> id;
                      if (dataType == TypeDef.type) {
                        id = moduleDef[ModuleDef.dataID][TypeDef.IDID];
                      } else if (dataType == InterfaceDef.type) {
                        id = moduleDef[ModuleDef.dataID][InterfaceDef.IDID];
                      } else if (dataType == ImplDef.type) {
                        id = moduleDef[ModuleDef.dataID][ImplDef.IDID];
                      } else if (dataType == ValueDef.type) {
                        id = moduleDef[ModuleDef.dataID][ValueDef.IDID];
                      } else {
                        throw Exception('unknown moduledef impl $dataType');
                      }
                      return ReaderWidget(
                        key: ValueKey(id.read(ctx)),
                        ctx: ctx,
                        builder: (_, ctx) {
                          final dataType =
                              moduleDef[ModuleDef.implID][ModuleDef.dataTypeID].read(ctx);
                          if (dataType == TypeDef.type) {
                            final name =
                                moduleDef[ModuleDef.dataID][TypeDef.treeID][TypeTree.nameID];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(TextSpan(children: [
                                  const TextSpan(text: 'type '),
                                  _inlineTextField(ctx, name.cast<String>()),
                                  const TextSpan(text: ' {'),
                                ])),
                                InsetChild(
                                  palEditor(
                                    ctx,
                                    TypeTree.type,
                                    moduleDef[ModuleDef.dataID][TypeDef.treeID],
                                  ),
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
                                  palEditor(
                                    ctx,
                                    TypeTree.type,
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
                                    Text(
                                        'impl of ${TypeTree.name(InterfaceDef.tree(interfaceDef))} {'),
                                    InsetChild(
                                      ExprEditor(
                                        ctx,
                                        moduleDef[ModuleDef.dataID][ImplDef.definitionID],
                                      ),
                                    ),
                                    const Text('}'),
                                  ],
                                );
                              },
                            );
                          } else if (dataType == ValueDef.type) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(children: [
                                    const TextSpan(text: 'let '),
                                    _inlineTextField(
                                      ctx,
                                      moduleDef[ModuleDef.dataID][ValueDef.nameID].cast<String>(),
                                    ),
                                    const TextSpan(text: ' ='),
                                  ]),
                                ),
                                InsetChild(
                                  ExprEditor(ctx, moduleDef[ModuleDef.dataID][ValueDef.valueID]),
                                ),
                              ],
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
      },
    ),
    Editable.mkImpl(
        dataType: TypeTree.type,
        editor: (ctx, typeTree) {
          final tag = typeTree[TypeTree.treeID][UnionTag.tagID].read(ctx);
          if (tag == TypeTree.recordID || tag == TypeTree.unionID) {
            final subTree = typeTree[TypeTree.treeID][UnionTag.valueID][Map.entriesID].cast<Dict>();
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
                    palEditor(ctx, TypeTree.type, subTree[key].whenPresent),
                  ),
                ]
              ],
            );
          } else if (tag == TypeTree.leafID) {
            return ExprEditor(ctx, typeTree[TypeTree.treeID][UnionTag.valueID]);
          } else {
            throw Exception('unknown type tree union case');
          }
        }),
  ],
);
final uiCtx = [Printable.module, palUIModule]
    .fold(coreCtx, (ctx, module) => Option.unwrap(Module.load(ctx, module)) as Ctx);

Widget palEditor(Ctx ctx, Object type, Cursor<Object> cursor) {
  return eval(
    ctx,
    FnApp.mk(
      editorFn,
      Literal.mk(
        TypeDef.asType(editorArgsDef),
        Dict({
          editorArgsDataTypeID: type,
          editorArgsCursorID: PalCursor.mk(cursor),
        }),
      ),
    ),
  ) as Widget;
}

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
        child: palEditor(uiCtx, Module.type, module),
      ),
    ],
  );
}

@reader
Widget _dataTreeEditor(
  Ctx ctx,
  Object typeTree,
  Cursor<Object> dataTree,
  Widget Function(Ctx, Cursor<Object>) renderLeaf,
) {
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
                DataTreeEditor(ctx, entry.value, dataTree[entry.key], renderLeaf),
              ),
            ] else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${TypeTree.name(entry.value)}: '),
                    AlignedWidgetSpan(
                      DataTreeEditor(ctx, entry.value, dataTree[entry.key], renderLeaf),
                    )
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
            DataTreeEditor(ctx, union[currentTag].unwrap!, dataTree[UnionTag.valueID], renderLeaf),
          ),
          const Text(')')
        ],
      );
    },
    leaf: (leaf) => renderLeaf(ctx, dataTree),
  );
}

@reader
Widget _exprEditor(BuildContext context, Ctx ctx, Cursor<Object> expr) {
  final placeholderFocusNode = useFocusNode();
  final wrapperFocusNode = useFocusNode();
  final exprType = expr[Expr.implID][Expr.dataTypeID].read(ctx);
  final exprData = expr[Expr.dataID];

  late final Widget child;
  if (exprType == Type.mk(FnExpr.typeDefID)) {
    late final Widget body;
    if (exprData[FnExpr.bodyID][UnionTag.tagID].read(ctx) == FnExpr.dartID) {
      body = const Text('dart implementation', style: TextStyle(fontStyle: FontStyle.italic));
    } else {
      body = ExprEditor(
        ctx.withBinding(Binding.mk(
          id: exprData[FnExpr.argIDID].read(ctx) as ID,
          type: exprData[FnExpr.argTypeID].read(ctx),
          name: exprData[FnExpr.argNameID].read(ctx) as String,
        )),
        exprData[FnExpr.bodyID][UnionTag.valueID],
      );
    }

    child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '('),
            _inlineTextField(ctx, exprData[FnExpr.argNameID].cast<String>()),
            const TextSpan(text: ': '),
            AlignedWidgetSpan(ExprEditor(ctx, exprData[FnExpr.argTypeID])),
            const TextSpan(text: ')'),
            const WidgetSpan(
              alignment: PlaceholderAlignment.bottom,
              baseline: TextBaseline.ideographic,
              child: Icon(
                Icons.arrow_right_alt,
                size: 16,
              ),
            ),
            if (exprData[FnExpr.returnTypeID][Option.valueID][UnionTag.tagID].read(ctx) ==
                Option.someID)
              AlignedWidgetSpan(
                ExprEditor(ctx, exprData[FnExpr.returnTypeID][Option.valueID][UnionTag.valueID]),
              )
            else
              const TextSpan(text: '_'),
            const TextSpan(text: ' {'),
          ]),
        ),
        InsetChild(body),
        const Text('}'),
      ],
    );
  } else if (exprType == TypeDef.asType(FnApp.typeDef)) {
    if (exprData[FnApp.fnID][Expr.implID][Expr.dataTypeID].read(ctx) ==
        TypeDef.asType(Var.typeDef)) {
      child = Text.rich(TextSpan(children: [
        AlignedWidgetSpan(ExprEditor(ctx, exprData[FnApp.fnID])),
        const TextSpan(text: '('),
        AlignedWidgetSpan(ExprEditor(ctx, exprData[FnApp.argID])),
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
                ExprEditor(ctx, exprData[FnApp.fnID]),
                ExprEditor(ctx, exprData[FnApp.argID]),
              ],
            ),
          ),
          const Text(')'),
        ],
      );
    }
  } else if (exprType == TypeDef.asType(RecordAccess.typeDef)) {
    final targetType = typeCheck(ctx, exprData[RecordAccess.targetID].read(ctx));

    child = Text.rich(TextSpan(children: [
      AlignedWidgetSpan(ExprEditor(ctx, exprData[RecordAccess.targetID])),
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
            currentItem: exprData[RecordAccess.memberID].read(ctx),
            buildItem: (memberID) => Text(TypeTree.name(record[memberID].unwrap!).toString()),
            onItemSelected: (key) => exprData[RecordAccess.memberID].set(key),
            child: Text(
              TypeTree.name(record[exprData[RecordAccess.memberID].read(ctx)].unwrap!).toString(),
            ),
          ));
        },
        none: () => const TextSpan(text: 'member', style: TextStyle(fontStyle: FontStyle.italic)),
      ),
    ]));
  } else if (exprType == TypeDef.asType(Var.typeDef)) {
    final varID = exprData[Var.IDID].read(ctx);
    child = Option.cases(
      ctx.getBinding(varID as ID),
      some: (binding) => Text(Binding.name(binding)),
      none: () => Text(
        'unknown var $varID',
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
    );
  } else if (exprType == TypeDef.asType(Literal.typeDef)) {
    child = Text(
      palPrint(ctx, Literal.getType(exprData.read(ctx)), Literal.getValue(exprData.read(ctx))),
    );
  } else if (exprType == Construct.type) {
    final typeDef = ctx.getType(exprData[Construct.dataTypeID][Type.IDID].read(ctx) as ID);

    child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${TypeTree.name(TypeDef.tree(typeDef))}('),
        InsetChild(
          DataTreeEditor(ctx, TypeDef.tree(typeDef), exprData[Construct.treeID], ExprEditor.new),
        ),
        const Text(')'),
      ],
    );
  } else if (exprType == TypeDef.asType(Placeholder.typeDef)) {
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
  } else if (exprType == List.mkExprType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in exprData[List.mkValuesID][List.itemsID].cast<Vec>().values(ctx)) ...[
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
