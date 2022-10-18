import 'dart:math';
import 'dart:core';
import 'dart:core' as dart;

import 'package:ctx/ctx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart' hide Dict, Vec;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart' as reified;
import 'package:knose/annotations.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/src/pal2/lang.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/src/pal2/print.dart';

part 'pal_editor.g.dart';

abstract class PalCursor {
  static final dataTypeID = ID.mk('dataType');
  static final cursorID = ID.mk('cursor');

  static final defID = ID.mk('Cursor');
  static final def = TypeDef.record(
    'Cursor',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      cursorID: TypeTree.mk('cursor', Type.lit(unit)),
    },
    id: defID,
    comptime: [dataTypeID],
  );

  static Object type(Object type) => Type.mk(defID, properties: [
        MemberHas.mkEquals([dataTypeID], Type.type, type)
      ]);

  static Object typeExpr(Object type) => Type.mkExpr(defID, properties: [
        MemberHas.mkEqualsExpr([dataTypeID], Type.lit(Type.type), type)
      ]);

  static Object mk(Cursor<Object> cursor) => Dict({cursorID: cursor});

  static Cursor<Object> cursor(Object palCursor) =>
      (palCursor as Dict)[cursorID].unwrap! as Cursor<Object>;
}

final palWidgetDef = TypeDef.unit('Widget');
final palWidget = TypeDef.asType(palWidgetDef);

abstract class Editable {
  static final dataTypeID = ID.mk('dataType');
  static final editorID = ID.mk('editor');
  static final editorArgID = ID.mk('editorArg');
  static final interfaceDef = InterfaceDef.record('Editable', {
    dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
    editorID: TypeTree.mk(
      'editor',
      Fn.typeExpr(
        argID: editorArgID,
        argType: PalCursor.typeExpr(Var.mk(dataTypeID)),
        returnType: Type.lit(palWidget),
      ),
    ),
  });

  static Object mkImpl({
    required Object dataType,
    required ID editor,
  }) =>
      ImplDef.mkDef(ImplDef.mk(
        implemented: InterfaceDef.id(interfaceDef),
        definition: Dict({
          dataTypeID: Type.lit(dataType),
          editorID: FnExpr.dart(
            argID: editorArgID,
            argName: 'editorArg',
            argType: Type.lit(PalCursor.type(dataType)),
            returnType: Type.lit(palWidget),
            body: editor,
          ),
        }),
      ));

  static Object mkParameterizedImpl({
    required String name,
    required Object argType,
    required Object Function(Object) dataType,
    required ID editor,
  }) =>
      ImplDef.mkParameterized(
        id: ID.mk(name),
        implemented: InterfaceDef.id(interfaceDef),
        argType: argType,
        definition: (arg) => Dict({
          dataTypeID: dataType(arg),
          editorID: FnExpr.pal(
            argID: editorArgID,
            argName: 'printArg',
            argType: dataType(arg),
            returnType: Type.lit(text),
            body: FnApp.mk(
              FnExpr.dart(
                argName: 'printArg',
                argType: Type.lit(Any.type),
                returnType: Type.lit(text),
                body: editor,
              ),
              Any.mkExpr(dataType(arg), Var.mk(editorArgID)),
            ),
          )
        }),
      );
}

final editorFn = Var.mk(ID.mk('editor'));
final editorArgsDataTypeID = ID.mk('dataType');
final editorArgsCursorID = ID.mk('cursor');
final editorArgsDef = TypeDef.record('EditorArgs', {
  editorArgsDataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
  editorArgsCursorID: TypeTree.mk('cursor', PalCursor.typeExpr(Var.mk(editorArgsDataTypeID))),
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
        argType: Type.lit(TypeDef.asType(editorArgsDef)),
        returnType: Type.lit(palWidget),
        body: palEditorInverseFnMap[_editorFn]!,
      ),
    ),
    Editable.mkImpl(
      dataType: Module.type,
      editor: palEditorInverseFnMap[_moduleEditorFn]!,
    ),
    Editable.mkImpl(
      dataType: TypeTree.type,
      editor: palEditorInverseFnMap[_typeTreeEditorFn]!,
    ),
  ],
);

@DartFn('1be6008b-3a4c-4901-be16-58760b31ff3f')
Object _editorFn(Ctx ctx, Object arg) {
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
  return eval(
    ctx,
    FnApp.mk(
      Literal.mk(
        Fn.type(
          argID: Editable.editorArgID,
          argType: cursorType,
          returnType: Type.lit(palWidget),
        ),
        impl[Editable.editorID].unwrap!,
      ),
      Literal.mk(cursorType, arg[editorArgsCursorID].unwrap!),
    ),
  ) as Widget;
}

@DartFn('ba3db78e-e181-4ff7-b94e-ecdc01b22e0e')
Object _typeTreeEditorFn(Ctx ctx, Object arg) {
  final typeTree = PalCursor.cursor(arg);
  final tag = typeTree[TypeTree.treeID][UnionTag.tagID].read(ctx);
  if (tag == TypeTree.recordID || tag == TypeTree.unionID) {
    final dict = typeTree[TypeTree.treeID][UnionTag.valueID][Map.entriesID].cast<Dict>();
    return InlineInset(contents: [
      for (final key in dict.keys.read(ctx))
        Inset(
          prefix: Text.rich(TextSpan(children: [
            if (dict[key].whenPresent[TypeTree.treeID][UnionTag.tagID].read(ctx) ==
                TypeTree.unionID)
              const TextSpan(text: 'union '),
            if (dict[key].whenPresent[TypeTree.treeID][UnionTag.tagID].read(ctx) ==
                TypeTree.recordID)
              const TextSpan(text: 'record '),
            _inlineTextSpan(ctx, dict[key].whenPresent[TypeTree.nameID].cast<String>()),
            const TextSpan(text: ': '),
          ])),
          contents: [
            palEditor(ctx.withoutBinding(key as ID), TypeTree.type, dict[key].whenPresent)
          ],
          suffix: const SizedBox(),
        )
    ]);
  } else if (tag == TypeTree.leafID) {
    return ExprEditor(ctx, typeTree[TypeTree.treeID][UnionTag.valueID], suffix: ', ');
  } else {
    throw Exception('unknown type tree union case');
  }
}

final uiCtx = [
  [Printable.fnMap, Printable.module],
  [palEditorFnMap, palUIModule]
].fold(
  coreCtx,
  (ctx, module) => Option.unwrap(Module.load(ctx.withFnMap(module[0] as FnMap), module[1])) as Ctx,
);

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
  final modules = useCursor(reified.Vec([
    Vec([langFnMap, coreModule]),
    Vec([Printable.fnMap, Printable.module]),
    Vec([palEditorFnMap, palUIModule])
  ]));
  final stale = useCursor(true);
  final moduleCtx = useCursor(Option.mk());
  useEffect(
    () => modules.listen((old, nu, diff) {
      if (!stale.read(Ctx.empty)) stale.set(true);
    }),
  );
  final expr = useCursor(placeholder);
  final currentModule = useCursor(modules[0][1][Module.IDID].read(ctx) as ID);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ReaderWidget(
        ctx: ctx,
        builder: (_, ctx) {
          final id = useCursor(ID.mk());
          return TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: "@DartFn('${id.read(Ctx.empty).id}')"));
              id.set(ID.mk());
            },
            child: Text(id.read(ctx).id),
          );
        },
      ),
      if (stale.read(ctx))
        TextButton(
          onPressed: () {
            stale.set(false);
            moduleCtx.set(modules.read(ctx).fold<Object>(
                  Option.mk(Ctx.empty),
                  (ctx, module) => Option.cases(
                    ctx,
                    some: (ctx) {
                      return Module.load((ctx as Ctx).withFnMap(module[0] as FnMap), module[1]);
                    },
                    none: () => Option.mk(),
                  ),
                ));
          },
          child: const Text('Load Modules'),
        ),
      ReaderWidget(
        ctx: ctx,
        builder: (_, ctx) => Option.cases(
          moduleCtx.read(ctx),
          some: (moduleCtx) => ExprEditor(moduleCtx as Ctx, expr),
          none: () => const Text('module load error!'),
        ),
      ),
      DropdownMenu<ID>(
        items: modules.values(ctx).map((m) => m[1][Module.IDID].read(ctx) as ID),
        currentItem: currentModule.read(ctx),
        onItemSelected: currentModule.set,
        buildItem: (id) => Text(
          modules
              .values(ctx)
              .firstWhere((m) => m[1][Module.IDID].read(ctx) == id)[1][Module.nameID]
              .read(ctx) as String,
        ),
        child: const Text('select module'),
      ),
      for (final module in modules.values(ctx))
        if (module[1][Module.IDID].read(ctx) == currentModule.read(ctx))
          Expanded(
            key: ValueKey(module[1][Module.IDID].read(ctx)),
            child: palEditor(uiCtx, Module.type, module[1]),
          ),
    ],
  );
}

ID _moduleDefID(Ctx ctx, Cursor<Object> def) {
  final dataType = def[ModuleDef.implID][ModuleDef.dataTypeID].read(ctx);
  if (dataType == TypeDef.type) {
    return def[ModuleDef.dataID][TypeDef.IDID].read(ctx) as ID;
  } else if (dataType == InterfaceDef.type) {
    return def[ModuleDef.dataID][InterfaceDef.IDID].read(ctx) as ID;
  } else if (dataType == ImplDef.type) {
    return def[ModuleDef.dataID][ImplDef.IDID].read(ctx) as ID;
  } else if (dataType == ValueDef.type) {
    return def[ModuleDef.dataID][ValueDef.IDID].read(ctx) as ID;
  } else {
    throw UnimplementedError('unknown module type $dataType');
  }
}

@DartFn('72213f44-7f10-4758-8a02-6451d8a8e961')
Object _moduleEditorFn(Ctx ctx, Object arg) => ModuleEditor(ctx, PalCursor.cursor(arg));

@reader
Widget _moduleEditor(BuildContext context, Ctx ctx, Cursor<Object> module) {
  final definitions = module[Module.definitionsID][List.itemsID].cast<Vec>();

  final childMap = useMemoized(() => <ID, Widget>{}, [module]);
  Widget childForDef(Ctx ctx, Cursor<Object> moduleDef) {
    final id = _moduleDefID(ctx, moduleDef);
    return childMap[id] ??= ReaderWidget(
      ctx: ctx,
      builder: (_, ctx) {
        final dataType = moduleDef[ModuleDef.implID][ModuleDef.dataTypeID].read(ctx);
        if (dataType == TypeDef.type || dataType == InterfaceDef.type) {
          late final String kind;
          late final Cursor<Object> typeTree;
          if (dataType == TypeDef.type) {
            kind = 'type';
            typeTree = moduleDef[ModuleDef.dataID][TypeDef.treeID];
          } else if (dataType == InterfaceDef.type) {
            kind = 'interface';
            typeTree = moduleDef[ModuleDef.dataID][InterfaceDef.treeID];
          } else {
            throw Error();
          }
          final name = _inlineTextSpan(ctx, typeTree[TypeTree.nameID].cast<String>());
          ctx = TypeTree.typeBindings(ctx, typeTree.read(ctx));
          return Inset(
            prefix: Text.rich(TextSpan(children: [
              TextSpan(text: '$kind '),
              name,
              const TextSpan(text: ' { '),
            ])),
            contents: [
              palEditor(
                ctx,
                TypeTree.type,
                typeTree,
              )
            ],
            suffix: const Text('}'),
          );
        } else if (dataType == ImplDef.type) {
          final interfaceDef = ctx.getInterface(
            moduleDef[ModuleDef.dataID][ImplDef.implementedID].read(ctx) as ID,
          );
          return Option.cases(
            Option.mk(interfaceDef),
            none: () => const Text('unknown interface'),
            some: (interfaceDef) {
              return Inset(
                prefix: Text(
                  'impl of ${TypeTree.name(InterfaceDef.tree(interfaceDef))} { ',
                ),
                contents: [
                  ExprEditor(
                    ctx,
                    moduleDef[ModuleDef.dataID][ImplDef.definitionID],
                  )
                ],
                suffix: const Text('}'),
              );
            },
          );
        } else if (dataType == ValueDef.type) {
          return Inset(
            prefix: Text.rich(TextSpan(children: [
              const TextSpan(text: 'let '),
              _inlineTextSpan(
                ctx,
                moduleDef[ModuleDef.dataID][ValueDef.nameID].cast<String>(),
              ),
              const TextSpan(text: ' = '),
            ])),
            contents: [ExprEditor(ctx, moduleDef[ModuleDef.dataID][ValueDef.valueID])],
            suffix: const SizedBox(),
          );
        } else {
          throw Exception('unknown ModuleDef type $dataType');
        }
      },
    );
  }

  Widget childForIndexedDef(Ctx ctx, IndexedValue<Cursor<Object>> indexedModuleDef) {
    return ReaderWidget(
      ctx: ctx,
      key: ValueKey(_moduleDefID(ctx, indexedModuleDef.value)),
      builder: (_, ctx) {
        final isOpen = useCursor(false);
        final dropdownFocus = useFocusNode();

        return DeferredDropdown(
          dropdownFocus: dropdownFocus,
          isOpen: isOpen,
          dropdown: AddDefinitionDropdown(
            ctx,
            dropdownFocus: dropdownFocus,
            addDefinition: (def) {
              definitions.insert(indexedModuleDef.index + 1, def);
              isOpen.set(false);
            },
          ),
          child: FocusableNode(
            onDelete: () => definitions.remove(indexedModuleDef.index),
            onAddBelow: () => isOpen.set(true),
            child: childForDef(
              ctx,
              indexedModuleDef.value,
            ),
          ),
        );
      },
    );
  }

  return FocusTraversalGroup(
    policy: HierarchicalOrderTraversalPolicy(),
    child: SingleChildScrollView(
      child: Inset(
        prefix: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'module '),
            _inlineTextSpan(ctx, module[Module.nameID].cast<String>()),
            const TextSpan(text: ' {'),
          ]),
        ),
        contents: [
          for (final indexedModuleDef in definitions.indexedValues(ctx))
            childForIndexedDef(ctx, indexedModuleDef)
        ],
        suffix: const Text('} '),
      ),
    ),
  );
}

@reader
Widget _dataTreeEditor(
  Ctx ctx,
  Object typeTree,
  Cursor<Object> dataTree,
  Widget Function(Ctx, Cursor<Object>, {String suffix}) renderLeaf, {
  String suffix = '',
}) {
  return TypeTree.treeCases(
    typeTree,
    record: (record) => InlineInset(contents: [
      for (final entry in record.entries)
        Inset(
          prefix: Text('${TypeTree.name(entry.value)}: '),
          contents: [
            DataTreeEditor(
              ctx,
              entry.value,
              dataTree[entry.key],
              renderLeaf,
              suffix: entry.key == record.entries.last.key ? '' : ', ',
            ),
          ],
          suffix: const SizedBox(),
        ),
    ]),
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
      return Inset(
        prefix: Text.rich(
          TextSpan(children: [AlignedWidgetSpan(dropdown), const TextSpan(text: '(')]),
        ),
        contents: [
          DataTreeEditor(
            ctx,
            union[currentTag].unwrap!,
            dataTree[UnionTag.valueID],
            renderLeaf,
          )
        ],
        suffix: Text(')$suffix'),
      );
    },
    leaf: (leaf) => renderLeaf(ctx, dataTree, suffix: suffix),
  );
}

@reader
Widget _exprEditor(BuildContext context, Ctx ctx, Cursor<Object> expr, {String suffix = ''}) {
  final placeholderFocusNode = useFocusNode();
  final wrapperFocusNode = useFocusNode();
  final exprType = expr[Expr.implID][Expr.dataTypeID].read(ctx);
  final exprData = expr[Expr.dataID];
  final typeError = useMemoized(
    () => GetCursor.compute(
      (ctx) => !Option.isPresent(typeCheck(ctx, expr.read(ctx))),
      ctx: ctx,
      compare: true,
    ),
    [expr],
  );

  late final Widget child;
  if (exprType == FnExpr.type) {
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

    child = Inset(
      prefix: Text.rich(
        TextSpan(children: [
          const TextSpan(text: '('),
          _inlineTextSpan(ctx, exprData[FnExpr.argNameID].cast<String>()),
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
      contents: [body],
      suffix: Text('}$suffix'),
    );
  } else if (exprType == FnApp.type) {
    if (exprData[FnApp.fnID][Expr.implID][Expr.dataTypeID].read(ctx) ==
        TypeDef.asType(Var.typeDef)) {
      child = Text.rich(TextSpan(children: [
        AlignedWidgetSpan(ExprEditor(ctx, exprData[FnApp.fnID])),
        const TextSpan(text: '('),
        AlignedWidgetSpan(ExprEditor(ctx, exprData[FnApp.argID])),
        TextSpan(text: ')$suffix'),
      ]));
    } else {
      child = Inset(
        prefix: const Text('apply('),
        contents: [
          ExprEditor(ctx, exprData[FnApp.fnID], suffix: ', '),
          ExprEditor(ctx, exprData[FnApp.argID]),
        ],
        suffix: Text(')$suffix'),
      );
    }
  } else if (exprType == RecordAccess.type) {
    final targetType = typeCheck(ctx, exprData[RecordAccess.targetID].read(ctx));

    child = Text.rich(TextSpan(children: [
      AlignedWidgetSpan(ExprEditor(ctx, exprData[RecordAccess.targetID])),
      const TextSpan(text: '.'),
      Option.cases(
        targetType,
        some: (type) {
          final typeDef = ctx.getType(Type.id(Literal.getValue(Expr.data(type))));
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
      TextSpan(text: suffix),
    ]));
  } else if (exprType == Var.type) {
    final varID = exprData[Var.IDID].read(ctx);
    child = Option.cases(
      ctx.getBinding(varID as ID),
      some: (binding) => Text(Binding.name(binding) + suffix),
      none: () => Text(
        'unknown var $varID$suffix',
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
    );
  } else if (exprType == Literal.type) {
    child = IntrinsicWidth(
      child: Text(
        palPrint(ctx, Literal.getType(exprData.read(ctx)), Literal.getValue(exprData.read(ctx))) +
            suffix,
      ),
    );
  } else if (exprType == Construct.type) {
    final typeDef = ctx.getType(exprData[Construct.dataTypeID][Type.IDID].read(ctx) as ID);

    child = Inset(
      prefix: Text('${TypeTree.name(TypeDef.tree(typeDef))}('),
      contents: [
        DataTreeEditor(
          ctx,
          TypeDef.tree(typeDef),
          exprData[Construct.treeID],
          ExprEditor.new,
        )
      ],
      suffix: Text(')$suffix'),
    );
  } else if (exprType == Placeholder.type) {
    return ReaderWidget(
      ctx: ctx,
      builder: (_, ctx) {
        final inputText = useCursor('');
        final isOpen = useCursor(false);
        return Focus(
          skipTraversal: true,
          onFocusChange: isOpen.set,
          child: DeferredDropdown(
            isOpen: isOpen,
            closeOnExit: false,
            dropdown: ReaderWidget(
              ctx: ctx,
              builder: (_, ctx) {
                final children = ctx.getBindings
                    .expand((binding) {
                      final bindingType = Binding.valueType(ctx, binding);
                      if (bindingType == Type.lit(TypeDef.type)) {
                        return Option.cases(Binding.value(ctx, binding),
                            none: () => <reified.Pair<String, Widget>>[],
                            some: (value) {
                              final name = '${TypeTree.name(TypeDef.tree(value))}.mk(...)';
                              return [
                                reified.Pair(
                                  name,
                                  ReaderWidget(
                                    ctx: ctx,
                                    builder: (_, ctx) => TextButton(
                                      onPressed: () {
                                        expr.set(Construct.mk(
                                          TypeDef.asType(value),
                                          TypeTree.instantiate(TypeDef.tree(value), placeholder),
                                        ));
                                        wrapperFocusNode.requestFocus();
                                      },
                                      child: Text(name),
                                    ),
                                  ),
                                ),
                              ];
                            });
                      } else {
                        return [
                          reified.Pair(
                            Binding.name(binding),
                            ReaderWidget(
                              ctx: ctx,
                              builder: (_, ctx) => TextButton(
                                onPressed: () {
                                  expr.set(Var.mk(Binding.id(binding)));
                                  wrapperFocusNode.requestFocus();
                                },
                                child: Text(
                                  '${Binding.name(binding)}: ${palPrint(ctx, Expr.type, Binding.valueType(ctx, binding))}',
                                ),
                              ),
                            ),
                          )
                        ];
                      }
                    })
                    .expand(
                      (pair) => [
                        if (pair.first.toLowerCase().startsWith(inputText.read(ctx).toLowerCase()))
                          pair.second
                      ],
                    )
                    .toList();

                return Container(
                  constraints: const BoxConstraints(maxHeight: 500, maxWidth: 500),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: children.length,
                    itemBuilder: (_, index) => Container(
                      alignment: AlignmentDirectional.centerStart,
                      child: children[index],
                    ),
                  ),
                );
              },
            ),
            child: Focus(
              skipTraversal: true,
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: RichText(
                  text: TextSpan(children: [
                    AlignedWidgetSpan(
                      IntrinsicWidth(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 40),
                          child: BoundTextFormField(
                            inputText,
                            ctx: ctx,
                            style: Theme.of(context).textTheme.bodyText2,
                            focusNode: placeholderFocusNode,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.only(left: 2, top: 4, bottom: 4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextSpan(text: suffix),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  } else if (exprType == List.mkExprType) {
    return Inset(
      prefix: const Text('['),
      suffix: Text(']$suffix'),
      contents: [
        for (final child in exprData[List.mkValuesID][List.itemsID].cast<Vec>().values(ctx))
          ExprEditor(ctx, child, suffix: ', '),
      ],
    );
  } else {
    throw Exception('unknown expr!! ${expr.read(ctx)}');
  }

  return FocusableNode(
    onDelete: () {
      expr.set(placeholder);
      placeholderFocusNode.requestFocus();
    },
    focusNode: wrapperFocusNode,
    child: ReaderWidget(
      ctx: ctx,
      builder: (_, ctx) => Container(
        decoration: BoxDecoration(
          border: typeError.read(ctx) ? Border.all(color: Colors.red) : null,
          borderRadius: const BorderRadius.all(Radius.circular(3)),
        ),
        child: child,
      ),
    ),
  );
}

@reader
Widget _focusableNode({
  FocusNode? focusNode,
  void Function()? onDelete,
  void Function()? onAddBelow,
  required Widget child,
}) {
  final wrapperFocusNode = focusNode ?? useFocusNode();

  return Shortcuts.manager(
    manager: NonTextEditingShortcutManager(
      shortcuts: {
        if (onDelete != null)
          const SingleActivator(LogicalKeyboardKey.backspace): VoidCallbackIntent(onDelete),
        if (onAddBelow != null)
          const SingleActivator(LogicalKeyboardKey.add, shift: true):
              VoidCallbackIntent(onAddBelow),
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
      child: Builder(
        builder: (context) => Container(
          decoration: BoxDecoration(
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
        ),
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

InlineSpan _inlineTextSpan(Ctx ctx, Cursor<String> text) {
  return AlignedWidgetSpan(InlineTextField(ctx, text));
}

@reader
Widget _inlineTextField(Ctx ctx, Cursor<String> text) {
  return IntrinsicWidth(
    child: Builder(
      builder: (context) => Theme(
        data: ThemeData(inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none)),
        child: BoundTextFormField(
          text,
          ctx: ctx,
          decoration: const InputDecoration.collapsed(hintText: null),
          style: Theme.of(context).textTheme.bodyText2,
        ),
      ),
    ),
  );
}

@reader
Widget _addDefinitionDropdown(
  BuildContext context,
  Ctx ctx, {
  required FocusNode dropdownFocus,
  required void Function(Object) addDefinition,
}) {
  final isOpen = useCursor(false);

  return DeferredDropdown(
    isOpen: isOpen,
    dropdown: SelectInterfaceDropdown(
      ctx,
      (interface) => addDefinition(
        ImplDef.mkDef(
          ImplDef.mk(
            implemented: InterfaceDef.id(interface),
            definition: TypeTree.instantiate(InterfaceDef.tree(interface), placeholder),
          ),
        ),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MySimpleDialogOption(
          focusNode: dropdownFocus,
          onPressed: () =>
              addDefinition(ValueDef.mk(id: ID.mk(), name: 'unnamed', value: placeholder)),
          child: const Text('Add Value Definition'),
        ),
        MySimpleDialogOption(
          onPressed: () => addDefinition(TypeDef.mkDef(TypeDef.unit('unnamed'))),
          child: const Text('Add Type Definition'),
        ),
        MySimpleDialogOption(
          onPressed: () => addDefinition(InterfaceDef.mkDef(InterfaceDef.record('unnamed', {}))),
          child: const Text('Add Interface Definition'),
        ),
        MySimpleDialogOption(
          closeOnSelect: false,
          onPressed: () => isOpen.set(true),
          child: const Text('Add Interface Implementation'),
        ),
      ],
    ),
  );
}

@reader
Widget _selectInterfaceDropdown(Ctx ctx, void Function(Object) selectedInterface) {
  final interfaces = ctx.getBindings.expand((b) => [
        if (Binding.valueType(ctx, b) == Type.lit(InterfaceDef.type))
          Option.unwrap(Binding.value(ctx, b))
      ]);

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final interface in interfaces)
        MySimpleDialogOption(
          onPressed: () => selectedInterface(interface),
          child: Text(TypeTree.name(InterfaceDef.tree(interface))),
        ),
    ],
  );
}

@reader
Widget _mySimpleDialogOption(
  BuildContext context, {
  required VoidCallback onPressed,
  required Widget child,
  FocusNode? focusNode,
  bool autofocus = false,
  bool closeOnSelect = true,
}) {
  return TextButton(
    autofocus: autofocus,
    focusNode: focusNode,
    onPressed: () {
      onPressed();
      if (closeOnSelect) InheritedValue.maybeOf<DropdownContext>(context)?.close();
    },
    child: child,
  );
}

extension _PalAccess on Cursor<Object> {
  Cursor<Object> operator [](Object id) => this.cast<Dict>()[id].whenPresent;
}

class _TrieList<T extends Object> extends Iterable<T> {
  T? element;
  dart.List<_TrieList<T>> children;

  _TrieList(this.element, [dart.List<_TrieList<T>>? children]) : children = children ?? [];

  @override
  Iterator<T> get iterator => elements.iterator;

  Iterable<T> get elements sync* {
    if (element != null) yield element!;
    for (final child in children) {
      yield* child;
    }
  }

  void removeWhere(bool Function(T) predicate) {
    if (element != null && predicate(element!)) element = null;
    for (final child in children) {
      child.removeWhere(predicate);
    }
  }
}

class HierarchicalOrderTraversalPolicy extends FocusTraversalPolicy
    with DirectionalFocusTraversalPolicyMixin {
  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    return sortDescendantsStatic(descendants);
  }

  static Iterable<FocusNode> sortDescendantsStatic(Iterable<FocusNode> descendants) {
    final sorted = _TrieList<FocusNode>(null);
    for (final descendant in descendants) {
      _place(sorted, descendant);
    }
    _sortSiblings(sorted);
    return sorted;
  }

  static void _place(_TrieList<FocusNode> sorted, FocusNode node) {
    if (sorted.isEmpty) {
      sorted.element = node;
    } else if (sorted.element == null || node.ancestors.contains(sorted.element)) {
      final children = <_TrieList<FocusNode>>[];
      for (final subTrie in sorted.children) {
        if (subTrie.element!.ancestors.contains(node)) {
          children.add(subTrie);
        } else if (node.ancestors.contains(subTrie.element!)) {
          _place(subTrie, node);
        }
      }
      sorted.children.removeWhere(children.contains);
      sorted.children.add(_TrieList(node, children));
    } else if (sorted.element!.ancestors.contains(node)) {
      sorted.children = [_TrieList(sorted.element, sorted.children)];
      sorted.element = node;
    } else {
      sorted.children = [_TrieList(sorted.element, sorted.children), _TrieList(node)];
      sorted.element = null;
    }
  }

  static void _sortSiblings(_TrieList<FocusNode> sorted) {
    mergeSort<_TrieList<FocusNode>>(sorted.children, compare: (t1, t2) {
      final heightDifference = t1.element!.offset.dy - t2.element!.offset.dy;
      if (heightDifference.round() != 0) return heightDifference.round();
      return t2.element!.offset.dx < t1.element!.offset.dx ? 1 : -1;
    });
    sorted.children.forEach(_sortSiblings);
  }
}

extension HierarchicalDescendants on FocusNode {
  Iterable<FocusNode> get hierarchicalTraversableDescendants {
    if (!descendantsAreFocusable) return const [];
    final descendants = _traversableDescendants;
    descendants.element = null;
    HierarchicalOrderTraversalPolicy._sortSiblings(descendants);
    descendants.removeWhere((node) => !node.canRequestFocus || node.skipTraversal);
    return descendants;
  }

  _TrieList<FocusNode> get _traversableDescendants {
    return _TrieList(this, [
      for (final child in children)
        if (child.descendantsAreFocusable) child._traversableDescendants
    ]);
  }
}

class InlineInset extends Inset {
  InlineInset({required super.contents, super.key})
      : super(
          prefix: const SizedBox(),
          suffix: const SizedBox(),
          inset: EdgeInsets.zero,
          drawGuideLine: false,
        );
}

class Inset extends MultiChildRenderObjectWidget {
  final EdgeInsetsGeometry inset;
  final bool drawGuideLine;

  Inset({
    required Widget prefix,
    required dart.List<Widget> contents,
    required Widget suffix,
    this.inset = const EdgeInsetsDirectional.only(start: 10, end: 2),
    this.drawGuideLine = true,
    super.key,
  }) : super(children: [prefix, ...contents, suffix]);

  @override
  RenderObject createRenderObject(BuildContext context) => RenderInset(
        inset: inset,
        textDirection: Directionality.of(context),
        drawGuideLine: drawGuideLine,
      );

  @override
  void updateRenderObject(BuildContext context, covariant RenderInset renderObject) {
    renderObject
      ..inset = inset
      ..textDirection = Directionality.of(context)
      ..drawGuideLine = drawGuideLine;
  }
}

class InsetParentData extends ContainerBoxParentData<RenderBox> {}

class _InsetChildren {
  final dart.List<RenderBox> children;

  _InsetChildren(this.children);

  RenderBox get prefix => children.first;
  RenderBox get suffix => children.last;
  Iterable<RenderBox> get contents => children.sublist(1, children.length - 1);
  Iterable<RenderBox> get all => children;
}

class RenderInset extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, InsetParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, InsetParentData> {
  static const textBaseline = TextBaseline.alphabetic;

  RenderInset({
    required EdgeInsetsGeometry inset,
    required TextDirection textDirection,
    required bool drawGuideLine,
  })  : _inset = inset,
        _textDirection = textDirection,
        _drawGuideLine = drawGuideLine;

  EdgeInsetsGeometry get inset => _inset;
  late EdgeInsetsGeometry _inset;
  set inset(EdgeInsetsGeometry value) {
    if (_inset != value) {
      _inset = value;
      markNeedsLayout();
    }
  }

  TextDirection get textDirection => _textDirection;
  late TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection != value) {
      _textDirection = value;
      markNeedsLayout();
    }
  }

  bool get drawGuideLine => _drawGuideLine;
  late bool _drawGuideLine;
  set drawGuideLine(bool value) {
    if (_drawGuideLine != value) {
      _drawGuideLine = value;
      markNeedsLayout();
    }
  }

  InsetParentData _parentData(RenderBox child) => child.parentData as InsetParentData;
  _InsetChildren _children() {
    var contentIterator = firstChild!;
    final children = <RenderBox>[];
    while (_parentData(contentIterator).nextSibling != null) {
      children.add(contentIterator);
      contentIterator = _parentData(contentIterator).nextSibling!;
    }
    children.add(contentIterator);
    return _InsetChildren(children);
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! InsetParentData) {
      child.parentData = InsetParentData();
    }
  }

  @override
  void performLayout() {
    final children = _children();
    final prefix = children.prefix;
    final contents = children.contents;
    final suffix = children.suffix;

    prefix.layout(constraints.loosen(), parentUsesSize: true);
    for (final content in contents) {
      content.layout(
        constraints.loosen().deflate(inset.resolve(textDirection)),
        parentUsesSize: true,
      );
    }
    suffix.layout(constraints.loosen(), parentUsesSize: true);

    final newLine = _needsNewLine(constraints, children);
    double maxBaselineDistance = 0.0;
    if (!newLine) {
      final allocatedSize = Size(
        children.all.fold(0, (p, c) => p + c.size.width),
        children.all.map((c) => c.size.height).fold(0, max),
      );

      double height = allocatedSize.height;
      double maxSizeAboveBaseline = 0;
      double maxSizeBelowBaseline = 0;
      for (final child in [prefix, ...contents, suffix]) {
        final double? distance = child.getDistanceToBaseline(textBaseline, onlyReal: true);
        if (distance != null) {
          maxBaselineDistance = max(maxBaselineDistance, distance);
          maxSizeAboveBaseline = max(distance, maxSizeAboveBaseline);
          maxSizeBelowBaseline = max(child.size.height - distance, maxSizeBelowBaseline);
          height = max(maxSizeAboveBaseline + maxSizeBelowBaseline, height);
        }
      }
      size = constraints.constrain(Size(allocatedSize.width, height));
    } else {
      final double contentsHeight =
          contents.fold(0, (height, content) => height + content.size.height);
      size = constraints.constrain(Size(
        [
          contents.map((c) => c.size.width).fold(0.0, max) + _inset.collapsedSize.width,
          prefix.size.width,
          suffix.size.width,
        ].fold(0, max),
        contentsHeight + prefix.size.height + suffix.size.height,
      ));
    }

    if (newLine) {
      _parentData(prefix).offset = Offset.zero;
      var cumulativeHeight = prefix.size.height;
      for (final content in contents) {
        _parentData(content).offset = Offset(inset.resolve(textDirection).left, cumulativeHeight);
        cumulativeHeight += content.size.height;
      }
      _parentData(suffix).offset = Offset(0, cumulativeHeight);
    } else {
      var cumulativeWidth = 0.0;
      for (final child in [prefix, ...contents, suffix]) {
        late final double height;
        final double? distance = child.getDistanceToBaseline(textBaseline, onlyReal: true);
        if (distance != null) {
          height = maxBaselineDistance - distance;
        } else {
          height = 0.0;
        }
        _parentData(child).offset = Offset(cumulativeWidth, height);
        cumulativeWidth += child.size.width;
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    if (!drawGuideLine) return;
    final children = _children();
    if (_needsNewLine(constraints, children)) {
      context.canvas.drawRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + _parentData(children.contents.first).offset.dy,
          2,
          children.contents.fold(0.0, (height, content) => height + content.size.height),
        ),
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  bool _needsNewLine(
    BoxConstraints constraints,
    _InsetChildren children,
  ) {
    final double contentsWidth =
        children.contents.fold(0, (width, content) => width + content.size.width);

    final narrowEnough = contentsWidth <=
        constraints.maxWidth - (children.prefix.size.width + children.suffix.size.width);
    // TODO: compute the magic height constraint here properly
    final shortEnough = children.contents.map((c) => c.size.height).fold(0.0, max) <= 25;
    return !narrowEnough || !shortEnough;
  }
}
