// ignore_for_file: body_might_complete_normally_nullable

import 'dart:io';
import 'dart:math';
import 'dart:core';
import 'dart:core' as dart;

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart' hide Placeholder, DropdownMenu;
import 'package:flutter/services.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart' hide Dict, Vec, Pair;
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart' as reified;
import 'package:infra_widgets/focusable_node.dart';
import 'package:infra_widgets/inherited_value.dart';
import 'package:infra_widgets/inset.dart';
import 'package:infra_widgets/inline_spans.dart';
import 'package:infra_widgets/non_text_editing_shortcut_manager.dart';
import 'package:infra_widgets/hierarchical_traversal.dart';
import 'package:knose/annotations.dart';
import 'package:knose/infra_widgets.dart';
import 'package:knose/src/pal2/lang.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/src/pal2/print.dart';

part 'pal_editor.g.dart';

abstract class PalCursor {
  static const dataTypeID = ID.constant(
      id: '2d46681f-1d00-4e9e-bd21-9a183b390ba5', hashCode: 225513056, label: 'dataType');
  static const cursorID =
      ID.constant(id: 'fcb8541a-28d8-4f28-8b09-61e6eaf6b41c', hashCode: 257160735, label: 'cursor');

  static const defID =
      ID.constant(id: '74f778b6-fae8-43f8-b09a-ce921a390f6a', hashCode: 421951690, label: 'Cursor');
  static final def = TypeDef.record(
    'Cursor',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      cursorID: TypeTree.mk('cursor', Type.lit(unit)),
    },
    id: defID,
    comptime: [dataTypeID],
  );

  static Object type(Object type) => Type.mk(defID, properties: {dataTypeID: type});

  static Object typeExpr(Object type) =>
      Type.mkExpr(defID, properties: [reified.Pair(dataTypeID, type)]);

  static Object mk(Cursor<Object> cursor) => Dict({cursorID: cursor});

  static Cursor<Object> cursor(Object palCursor) =>
      (palCursor as Dict)[cursorID].unwrap! as Cursor<Object>;
}

final palWidgetDef = TypeDef.unit(
  'Widget',
  id: const ID.constant(id: 'f6665037-10f6-44be-a53a-ccd35eb50577', hashCode: 51471329),
);
final palWidget = TypeDef.asType(palWidgetDef);

abstract class Editable {
  static const dataTypeID = ID.constant(
      id: '0905d2f2-2e84-4ca0-b1d7-724684e9c472', hashCode: 472978359, label: 'dataType');
  static const editorID =
      ID.constant(id: '0031e1a6-f48d-4957-9a62-75934f7a4f6a', hashCode: 31945668, label: 'editor');
  static const editorArgID = ID.constant(
      id: '426e7931-6570-48f1-ae60-4d84ce84046a', hashCode: 39320343, label: 'editorArg');
  static final interfaceDef = InterfaceDef.record(
    'Editable',
    {
      dataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
      editorID: TypeTree.mk(
        'editor',
        Fn.typeExpr(
          argID: editorArgID,
          argType: PalCursor.typeExpr(Var.mk(dataTypeID)),
          returnType: Type.lit(palWidget),
        ),
      ),
    },
    id: const ID.constant(id: 'aa48c74f-5cf2-45bf-82e5-a0cd7d3485cf', hashCode: 117434805),
  );
}

final editorFn = Var.mk(const ID.constant(
    id: '35d520d1-aebe-438b-bd47-54b2e9b616eb', hashCode: 497128495, label: 'editor'));
const editorArgsDataTypeID =
    ID.constant(id: 'cd8dca0e-2f10-4e2e-a0b0-e0b0d18e1f2b', hashCode: 308108711, label: 'dataType');
const editorArgsCursorID =
    ID.constant(id: '88058ac7-242a-4536-92e9-7a977b581714', hashCode: 14102665, label: 'cursor');
final editorArgsDef = TypeDef.record(
  'EditorArgs',
  {
    editorArgsDataTypeID: TypeTree.mk('dataType', Type.lit(Type.type)),
    editorArgsCursorID: TypeTree.mk('cursor', PalCursor.typeExpr(Var.mk(editorArgsDataTypeID))),
  },
  id: const ID.constant(id: '879e1f46-a82d-41d4-92cb-8f97a2fb4253', hashCode: 246565902),
);

const palUIModuleID = ID.constant(
    id: '8ed69fc4-51c8-4853-9ecb-bb245ccf2706', hashCode: 225295658, label: 'palUIModule');

@DartFn('1be6008b-3a4c-4901-be16-58760b31ff3f')
Object _editorFn(Ctx ctx, Object arg) {
  final impl = Option.unwrap(
    dispatch(
      ctx,
      InterfaceDef.id(Editable.interfaceDef),
      InterfaceDef.implType(Editable.interfaceDef, {
        Editable.dataTypeID: (arg as Dict)[editorArgsDataTypeID].unwrap!,
      }),
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
@reader
Widget _typeTreeEditor(Ctx ctx, Object arg) {
  final typeTree = PalCursor.cursor(arg);

  Widget treeForMap(Cursor<Object> map) {
    final dict = map[Map.entriesID].cast<Dict>();
    return InlineInset(contents: [
      for (final key in dict.keys.read(ctx))
        ReaderWidget(
          ctx: ctx,
          key: ValueKey(key),
          builder: (_, ctx) {
            final isOpen = useCursor(false);
            final childTree = dict[key].whenPresent;
            final childTag = childTree[TypeTree.treeID][UnionTag.tagID].read(ctx);
            final focusNodes = {
              for (final tag in {TypeTree.recordID, TypeTree.unionID, TypeTree.leafID})
                tag: useFocusNode(),
            };
            return Actions(
              actions: {
                AddBelowIntent: CallbackAction(
                  onInvoke: (_) => dict[ID.mk()] = TypeTree.mk('unnamed', placeholder),
                ),
                DeleteIntent: CallbackAction(onInvoke: (_) => dict.remove(key)),
                ChangeKindIntent: CallbackAction(onInvoke: (_) => isOpen.set(true)),
                CopyIDIntent: CallbackAction(onInvoke: (_) => copyID(key as ID)),
              },
              child: DeferredDropdown(
                isOpen: isOpen,
                dropdownFocus: focusNodes[childTag]!,
                dropdown: Column(children: [
                  TextButton(
                    focusNode: focusNodes[TypeTree.recordID]!,
                    onPressed: () => childTree.set(
                      TypeTree.record('fieldName', {ID.mk(): childTree.read(Ctx.empty)}),
                    ),
                    child: const Text('record'),
                  ),
                  TextButton(
                    focusNode: focusNodes[TypeTree.unionID]!,
                    onPressed: () => childTree.set(
                      TypeTree.union('fieldName', {ID.mk(): childTree.read(Ctx.empty)}),
                    ),
                    child: const Text('union'),
                  ),
                  TextButton(
                    focusNode: focusNodes[TypeTree.leafID]!,
                    onPressed: () {
                      void setForMap(GetCursor<Object> map) {
                        childTree.set(
                          map[Map.entriesID].cast<Dict>().read(Ctx.empty).values.firstOr(
                                () => TypeTree.mk('fieldName', placeholder),
                              ),
                        );
                      }

                      childTree[TypeTree.treeID].unionCases(ctx, {
                        TypeTree.leafID: (_) {},
                        TypeTree.recordID: setForMap,
                        TypeTree.unionID: setForMap,
                      });
                    },
                    child: const Text('leaf'),
                  ),
                ]),
                child: FocusableNode(
                  child: Inset(
                    prefix: Text.rich(TextSpan(children: [
                      if (childTag == TypeTree.unionID) const TextSpan(text: 'union '),
                      if (childTag == TypeTree.recordID) const TextSpan(text: 'record '),
                      _inlineTextSpan(ctx, dict[key].whenPresent[TypeTree.nameID].cast<String>()),
                      const TextSpan(text: ': '),
                    ])),
                    contents: [
                      TypeTreeEditor(
                          ctx.withoutBinding(key as ID), PalCursor.mk(dict[key].whenPresent))
                      // palEditor(ctx.withoutBinding(key as ID), TypeTree.type, dict[key].whenPresent)
                    ],
                    suffix: const SizedBox(),
                  ),
                ),
              ),
            );
          },
        )
    ]);
  }

  return typeTree[TypeTree.treeID].unionCases(ctx, {
    TypeTree.recordID: treeForMap,
    TypeTree.unionID: treeForMap,
    TypeTree.leafID: (expr) => ExprEditor(ctx, expr, suffix: ', ')
  });
}

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
  final saveDir = Directory('pal');

  final modules = useCursor(const Vec());
  final moduleCtx = useMemoized(
    () => Module.loadReactively(
      ctx.withFnMap(langFnMap).withFnMap(Printable.fnMap).withFnMap(palEditorFnMap),
      modules,
    ),
    [],
  );

  Future<void> loadFiles() async {
    final files = await saveDir.list().toList();
    modules.set(
      Vec([
        for (final file in files)
          if (file is File) deserialize(file.readAsStringSync()) as Object
      ]),
    );
  }

  useEffect(() {
    loadFiles();
  }, []);

  final currentModule = useCursor(Option.mk());

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(children: [
        TextButton(
          onPressed: () {
            for (final module in modules.read(Ctx.empty)) {
              final name = Module.name(module);
              final file = File('${saveDir.path}/$name.pal');
              file.writeAsString(serialize(module, '  '));
            }
          },
          child: const Text('save modules'),
        ),
        TextButton(onPressed: loadFiles, child: const Text('load modules')),
        TextButtonDropdown(
          dropdown: Column(
            children: [
              for (final migration in migrations)
                Row(children: [
                  Text('$migration:'),
                  TextButton(
                    onPressed: () => modules.mut(migration.migrate),
                    child: const Text('do'),
                  ),
                  TextButton(
                    onPressed: () => modules.mut(migration.unmigrate),
                    child: const Text('undo'),
                  ),
                ])
            ],
          ),
          child: const Text('run migration...'),
        ),
        TextButton(
          onPressed: () {
            final files = [
              File('lib/src/app_widgets/pal_editor.dart'),
              File('lib/src/pal2/lang.dart'),
              File('lib/src/pal2/print.dart'),
            ];
            for (final file in files) {
              file.readAsLines().then((lines) {
                file.writeAsString([
                  for (final line in lines)
                    line.replaceFirstMapped(
                      RegExp('id: \'([^\']+)\', hashCode: ([0-9]+)'),
                      (match) {
                        final result = "id: '${match[1]}', hashCode: ${Hash.all(match[1], null)}";
                        return result;
                      },
                    ),
                ].join('\n'));
              }, onError: (Object e) => throw e);
            }
          },
          child: const Text('check id hashcodes'),
        ),
        if (false)
          // ignore: dead_code
          TextButton(
            onPressed: () {
              final idString = StringBuffer();
              idString.writeln('const ids = [');
              for (final _ in range(1000)) {
                final id = ID.mk();
                idString.writeln('ID.constant(id: \'${id.id}\', hashCode: ${id.hashCode}),');
              }
              idString.writeln('];');
              Clipboard.setData(ClipboardData(text: '$idString'));
            },
            child: const Text('generate IDs'),
          ),
        Shortcuts(
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.keyC):
                VoidCallbackIntent(() => copyID(ID.mk())),
            const SingleActivator(LogicalKeyboardKey.keyD):
                VoidCallbackIntent(() => copyDartFn(ID.mk())),
          },
          child: TextButton(onPressed: () {}, child: const Text('generate ID')),
        ),
      ]),
      DropdownMenu(
        items: modules
            .values(ctx)
            .map((m) => Option.mk(m[Module.IDID].read(ctx)))
            .followedBy([Option.mk()]),
        currentItem: currentModule.read(ctx),
        onItemSelected: (item) {
          currentModule.set(Option.mk(Option.unwrap(item, orElse: () {
            final id = ID.mk();
            modules.add(
              Vec([
                // ignore: prefer_collection_literals
                FnMap(),
                Module.mk(
                  id: id,
                  name: 'untitled',
                  definitions: [ValueDef.mk(id: id, name: 'value', value: placeholder)],
                )
              ]),
            );
            return id;
          })));
        },
        buildItem: (id) => Text(Option.cases(
          id,
          none: () => 'New module',
          some: (id) => modules
              .values(ctx)
              .firstWhere((m) => m[Module.IDID].read(ctx) == id)[Module.nameID]
              .read(ctx) as String,
        )),
        child: const Text('select module'),
      ),
      // ReaderWidget(
      //   ctx: ctx,
      //   builder: (_, ctx) {
      //     final expr = useCursor(placeholder);
      //     final typeResult = typeCheck(moduleCtx.read(ctx), expr.read(ctx));

      //     return Container(
      //       padding: const EdgeInsets.all(10),
      //       decoration: BoxDecoration(border: Border.all()),
      //       child: Column(
      //         mainAxisSize: MainAxisSize.min,
      //         crossAxisAlignment: CrossAxisAlignment.start,
      //         children: [
      //           const Text('playground'),
      //           PalScaffold(ExprEditor(moduleCtx.read(ctx), expr)),
      //           Result.cases(
      //             typeResult,
      //             error: (msg) => Text(msg),
      //             ok: (type) => Text(
      //               'result: ${palPrint(moduleCtx.read(ctx), Literal.getValue(Expr.data(type)), eval(moduleCtx.read(ctx), expr.read(ctx)))}',
      //             ),
      //           ),
      //         ],
      //       ),
      //     );
      //   },
      // ),
      for (final module in modules.values(ctx))
        if (Option.mk(module[Module.IDID].read(ctx)) == currentModule.read(ctx))
          Expanded(
            key: ValueKey(module[Module.IDID].read(ctx)),
            child: PalScaffold(ModuleEditor(moduleCtx.read(ctx), module)),
          ),
    ],
  );
}

@DartFn('72213f44-7f10-4758-8a02-6451d8a8e961')
Object _moduleEditorFn(Ctx ctx, Object arg) => ModuleEditor(ctx, PalCursor.cursor(arg));

@reader
Widget _palScaffold(Widget child) {
  return Shortcuts.manager(
    manager: NonTextEditingShortcutManager(shortcuts: palShortcuts),
    child: FocusTraversalGroup(policy: HierarchicalOrderTraversalPolicy(), child: child),
  );
}

@reader
Widget _moduleEditor(BuildContext context, Ctx ctx, Cursor<Object> module) {
  final definitions = module[Module.definitionsID];
  final definitionIDs = definitions[OrderedMap.keyOrderID][List.itemsID].cast<Vec>();
  final definitionMap = definitions[OrderedMap.valueMapID][Map.entriesID].cast<Dict>();

  final childMap = useMemoized(() => <ID, Widget>{}, [module]);
  Widget childForDef(Ctx ctx, ID id) {
    return childMap[id] ??= ReaderWidget(
      ctx: ctx,
      builder: (_, ctx) {
        final moduleDef = definitionMap[id].whenPresent;
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
          return Actions(
            actions: {
              AddWithinIntent: CallbackAction(
                onInvoke: (_) {
                  typeTree[TypeTree.treeID].unionCases(Ctx.empty, {
                    TypeTree.recordID: (map) => map[Map.entriesID].cast<Dict>()[ID.mk()] =
                        TypeTree.mk('fieldName', Type.lit(unit)),
                    TypeTree.unionID: (_) {},
                    TypeTree.leafID: (_) {},
                  });
                },
              ),
            },
            child: FocusableNode(
              child: Inset(
                prefix: Text.rich(TextSpan(children: [
                  TextSpan(text: '$kind '),
                  name,
                  const TextSpan(text: ' { '),
                ])),
                contents: [TypeTreeEditor(ctx, PalCursor.mk(typeTree))],
                suffix: const Text('}'),
              ),
            ),
          );
        } else if (dataType == ImplDef.type) {
          final interfaceDef = ctx.getInterface(
            moduleDef[ModuleDef.dataID][ImplDef.implementedID].read(ctx) as ID,
          );
          return FocusableNode(
            child: Option.cases(
              Option.mk(interfaceDef),
              none: () => const Text('unknown interface'),
              some: (interfaceDef) {
                return Inset(
                  prefix: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'impl '),
                    _inlineTextSpan(
                        ctx, moduleDef[ModuleDef.dataID][ImplDef.nameID].cast<String>()),
                    TextSpan(text: ' of ${TypeTree.name(InterfaceDef.tree(interfaceDef))} { '),
                  ])),
                  contents: [
                    ExprEditor(
                      ctx,
                      moduleDef[ModuleDef.dataID][ImplDef.definitionID],
                    )
                  ],
                  suffix: const Text('}'),
                );
              },
            ),
          );
        } else if (dataType == ValueDef.type) {
          return FocusableNode(
            child: Inset(
              prefix: Text.rich(TextSpan(children: [
                const TextSpan(text: 'let '),
                _inlineTextSpan(
                  ctx,
                  moduleDef[ModuleDef.dataID][ValueDef.nameID][Fn.bodyID][UnionTag.valueID]
                          [Expr.dataID][Literal.valueID]
                      .cast<String>(),
                ),
                const TextSpan(text: ' = '),
              ])),
              contents: [ExprEditor(ctx, moduleDef[ModuleDef.dataID][ValueDef.valueID])],
              suffix: const SizedBox(),
            ),
          );
        } else {
          throw Exception('unknown ModuleDef type $dataType');
        }
      },
    );
  }

  Widget childForID(Ctx ctx, ID id) {
    return ReaderWidget(
      ctx: ctx,
      key: ValueKey(id),
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
              final index = definitionIDs.read(Ctx.empty).indexOf(id);
              if (index == null) return;
              final newID = ModuleDef.idFor(def);
              definitionMap[newID] = def;
              definitionIDs.insert(index + 1, newID);
              isOpen.set(false);
            },
          ),
          child: Actions(
            actions: {
              AddBelowIntent: CallbackAction(onInvoke: (_) => isOpen.set(true)),
              DeleteIntent: CallbackAction(onInvoke: (_) {
                final index = definitionIDs.read(Ctx.empty).indexOf(id);
                if (index == null) return;
                definitionIDs.remove(index);
                definitionMap.remove(id);
              }),
              ShiftUpIntent: CallbackAction(onInvoke: (_) {
                final index = definitionIDs.read(Ctx.empty).indexOf(id);
                if (index != null && index > 0) {
                  definitionIDs[index] = definitionIDs[index - 1].read(Ctx.empty);
                  definitionIDs[index - 1] = id;
                }
              }),
              ShiftDownIntent: CallbackAction(onInvoke: (_) {
                final index = definitionIDs.read(Ctx.empty).indexOf(id);
                if (index != null && index < definitionIDs.length.read(Ctx.empty) - 1) {
                  definitionIDs[index] = definitionIDs[index + 1].read(Ctx.empty);
                  definitionIDs[index + 1] = id;
                }
              }),
              CopyIDIntent: CallbackAction(onInvoke: (_) {
                copyID(id);
              }),
            },
            child: childForDef(ctx, id),
          ),
        );
      },
    );
  }

  return SingleChildScrollView(
    child: Inset(
      repaintBoundaries: true,
      prefix: Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'module '),
          _inlineTextSpan(ctx, module[Module.nameID].cast<String>()),
          const TextSpan(text: ' {'),
        ]),
      ),
      contents: [for (final id in definitionIDs.read(ctx)) childForID(ctx, id as ID)],
      suffix: const Text('} '),
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
    record: (record) {
      if (record.length == 1) {
        return DataTreeEditor(
          ctx,
          record.values.single,
          dataTree[record.keys.single],
          renderLeaf,
        );
      }
      return InlineInset(contents: [
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
      ]);
    },
    union: (union) {
      final currentTag = dataTree[UnionTag.tagID].read(ctx);
      final dropdown = IntrinsicWidth(
        child: DropdownMenu<Object>(
          style: smallButtonStyle,
          items: [...union.keys],
          currentItem: currentTag,
          buildItem: (tag) => Text(TypeTree.name(union[tag].unwrap!).toString()),
          onItemSelected: (newTag) {
            dataTree.set(
              UnionTag.mk(newTag as ID, TypeTree.instantiate(union[newTag].unwrap!, placeholder)),
            );
          },
          child: Text(union[currentTag].cases(some: TypeTree.name, none: () => 'unknown case!')),
        ),
      );
      return Inset(
        prefix: Text.rich(
          TextSpan(children: [AlignedWidgetSpan(dropdown), const TextSpan(text: '(')]),
        ),
        contents: [
          dataTree.unionCases(
            ctx,
            {
              for (final entry in union.entries)
                entry.key as ID: (value) => DataTreeEditor(ctx, entry.value, value, renderLeaf),
            },
            unknown: () => Container(),
          ),
        ],
        suffix: Text(')$suffix'),
      );
    },
    leaf: (leaf) => renderLeaf(ctx, dataTree, suffix: suffix),
  );
}

@reader
Widget _exprEditor(
  BuildContext context,
  Ctx ctx,
  Cursor<Object> expr, {
  String suffix = '',
  void Function()? onDelete,
}) {
  final wrapperFocusNode = useFocusNode();
  final exprType = expr[Expr.implID][Expr.dataTypeID].read(ctx);
  final exprData = expr[Expr.dataID];

  late final Widget child;
  if (exprType == FnExpr.type) {
    final body = exprData[FnExpr.bodyID].unionCases(ctx, {
      FnExpr.dartID: (id) => Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'dart('),
              AlignedWidgetSpan(TextButtonDropdown(
                style: smallButtonStyle,
                dropdown: GenericPlaceholder(
                  ctx,
                  entries: GetCursor(reified.Vec([
                    for (final fnID in ctx.allDartFns)
                      PlaceholderEntry(name: fnID.label!, onPressed: () => id.set(fnID))
                  ])),
                ),
                child: Text(ctx.getFnName(id.read(ctx) as ID)),
              )),
              const TextSpan(text: ')'),
            ]),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
      FnExpr.palID: (expr) => ReaderWidget(
            ctx: ctx,
            builder: (_, ctx) {
              final argType = Result.flatMap(
                typeCheck(ctx, exprData[FnExpr.argTypeID].read(ctx)),
                (typeExpr) => assignableErr(
                  ctx,
                  Type.lit(Type.type),
                  typeExpr,
                  '',
                  () => reduce(ctx, exprData[FnExpr.argTypeID].read(ctx)),
                ),
              );
              return ExprEditor(
                ctx.withBinding(Binding.mk(
                  id: exprData[FnExpr.argIDID].read(ctx) as ID,
                  type: argType,
                  name: exprData[FnExpr.argNameID].read(ctx) as String,
                )),
                expr,
              );
            },
          ),
    });

    return Actions(
      actions: {
        ChangeKindIntent: CallbackAction(onInvoke: (_) {
          exprData[FnExpr.bodyID].unionCases(Ctx.empty, {
            FnExpr.dartID: (_) => exprData[FnExpr.bodyID].set(FnExpr.palBody(placeholder)),
            FnExpr.palID: (_) => exprData[FnExpr.bodyID].set(FnExpr.dartBody(ID.placeholder)),
          });
        }),
      },
      child: ExprFocusableNode(
        ctx,
        expr: expr,
        focusNode: wrapperFocusNode,
        onDelete: onDelete,
        child: Inset(
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
        ),
      ),
    );
  } else if (exprType == FnTypeExpr.type) {
    child = Inset(
      prefix: Text.rich(
        TextSpan(children: [
          const TextSpan(text: '('),
          _inlineTextSpan(ctx, exprData[FnTypeExpr.argNameID].cast<String>()),
          const TextSpan(text: ': '),
          AlignedWidgetSpan(ExprEditor(ctx, exprData[FnTypeExpr.argTypeID])),
          const TextSpan(text: ')'),
          const WidgetSpan(
            alignment: PlaceholderAlignment.bottom,
            baseline: TextBaseline.ideographic,
            child: Icon(
              Icons.arrow_right_alt,
              size: 16,
            ),
          ),
        ]),
      ),
      contents: [ExprEditor(ctx, exprData[FnTypeExpr.returnTypeID], suffix: suffix)],
    );
  } else if (exprType == FnApp.type) {
    child = FnAppEditor(ctx, fnApp: exprData, suffix: suffix);
  } else if (exprType == RecordAccess.type) {
    final targetType = typeCheck(ctx, exprData[RecordAccess.targetID].read(ctx));

    child = Text.rich(TextSpan(children: [
      AlignedWidgetSpan(ExprEditor(ctx, exprData[RecordAccess.targetID])),
      const TextSpan(text: '.'),
      Result.cases(
        targetType,
        ok: (type) {
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
        error: (_) => const TextSpan(text: 'member', style: TextStyle(fontStyle: FontStyle.italic)),
      ),
      TextSpan(text: suffix),
    ]));
  } else if (exprType == Var.type) {
    final varID = exprData[Var.IDID].read(ctx);
    child = Option.cases(
      ctx.getBinding(varID as ID),
      some: (binding) => Text(Binding.name(ctx, binding) + suffix),
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
    child = ConstructEditor(ctx, exprData: exprData, suffix: suffix);
  } else if (exprType == Placeholder.type) {
    return PlaceholderEditor(ctx, expr: expr, focusNode: wrapperFocusNode, suffix: suffix);
  } else if (exprType == DotPlaceholder.type) {
    child = DotPlaceholderEditor(ctx, expr: expr, suffix: suffix);
  } else if (exprType == List.mkExprType) {
    final children = exprData[List.mkValuesID][List.itemsID].cast<Vec>();
    return Actions(
      actions: {
        AddWithinIntent: CallbackAction(onInvoke: (_) => children.insert(0, placeholder)),
      },
      child: ExprFocusableNode(
        ctx,
        expr: expr,
        focusNode: wrapperFocusNode,
        onDelete: onDelete,
        child: Inset(
          prefix: Text.rich(TextSpan(children: [
            const TextSpan(text: '<'),
            AlignedWidgetSpan(ExprEditor(ctx, exprData[List.mkTypeID])),
            const TextSpan(text: '>['),
          ])),
          contents: [
            for (final child in children.indexedValues(ctx))
              Actions(
                actions: {
                  AddBelowIntent: CallbackAction(
                    onInvoke: (_) => children.insert(child.index + 1, placeholder),
                  ),
                },
                child: ExprEditor(
                  ctx,
                  child.value,
                  suffix: ', ',
                  onDelete: () => children.remove(child.index),
                ),
              ),
          ],
          suffix: Text(']$suffix'),
        ),
      ),
    );
  } else if (exprType == Map.mkType) {
    final children = exprData[Map.mkEntriesID][List.itemsID].cast<Vec>();
    return Actions(
      actions: {
        AddWithinIntent: CallbackAction(
          onInvoke: (_) => children.insert(0, Pair.mk(placeholder, placeholder)),
        ),
      },
      child: ExprFocusableNode(
        ctx,
        expr: expr,
        focusNode: wrapperFocusNode,
        onDelete: onDelete,
        child: Inset(
          prefix: Text.rich(TextSpan(children: [
            const TextSpan(text: '<'),
            AlignedWidgetSpan(ExprEditor(ctx, exprData[Map.mkKeyID])),
            const TextSpan(text: ', '),
            AlignedWidgetSpan(ExprEditor(ctx, exprData[Map.mkValueID])),
            const TextSpan(text: '>{'),
          ])),
          contents: [
            for (final child in children.indexedValues(ctx))
              Actions(
                actions: {
                  AddBelowIntent: CallbackAction(
                    onInvoke: (_) => children.insert(
                      child.index + 1,
                      Pair.mk(placeholder, placeholder),
                    ),
                  ),
                  DeleteIntent: CallbackAction(onInvoke: (_) => children.remove(child.index)),
                },
                child: FocusableNode(
                  child: Inset(
                    prefix: ExprEditor(
                      ctx,
                      child.value[Pair.firstID],
                      suffix: ': ',
                    ),
                    contents: [
                      ExprEditor(
                        ctx,
                        child.value[Pair.secondID],
                        suffix: ', ',
                      )
                    ],
                  ),
                ),
              ),
          ],
          suffix: Text('}$suffix'),
        ),
      ),
    );
  } else {
    throw Exception('unknown expr!! ${expr.read(ctx)}');
  }

  return ExprFocusableNode(
    ctx,
    expr: expr,
    focusNode: wrapperFocusNode,
    onDelete: onDelete,
    child: child,
  );
}

@reader
Widget _exprFocusableNode(
  BuildContext context,
  Ctx ctx, {
  required Cursor<Object> expr,
  required FocusNode focusNode,
  void Function()? onDelete,
  required Widget child,
}) {
  final typeError = useMemoized(
    () => GetCursor.compute(
      (ctx) => Result.cases(
        typeCheck(ctx, expr.read(ctx)),
        ok: (_) => Option.mk(),
        error: (err) => Option.mk(err),
      ),
      ctx: ctx,
      compare: true,
    ),
    [expr],
  );
  final isHovered = useCursor(false);
  final showHover = useMemoized(
    () => GetCursor.compute(
      (ctx) => Option.isPresent(typeError.read(ctx)) && isHovered.read(ctx),
      ctx: ctx,
      compare: true,
    ),
    [expr],
  );

  return FollowingDeferredPainter(
    ctx: ctx,
    isOpen: showHover,
    childAnchor: AlignmentDirectional.topStart,
    overlayAnchor: AlignmentDirectional.bottomStart,
    offset: const Offset(5, -5),
    modifyConstraints: (constraints) => constraints.loosen().copyWith(
          maxWidth: max(constraints.maxWidth, 500),
          maxHeight: double.infinity,
        ),
    deferee: ReaderWidget(
      ctx: ctx,
      builder: (_, ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          boxShadow: const [_myBoxShadow],
        ),
        child: Text(Option.unwrap(typeError.read(ctx)) as String),
      ),
    ),
    child: Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyR, shift: true):
            ReplaceParentIntent(() => expr.read(Ctx.empty))
      },
      child: CallbackActions(
        actions: [
          ActOn<DeleteIntent>((_) => onDelete == null ? expr.set(placeholder) : onDelete()),
          ActOn<AddDotIntent>((_) => expr.set(DotPlaceholder.mk(expr.read(Ctx.empty)))),
          ActOn<AddFnAppIntent>((_) => expr.set(FnApp.mk(expr.read(Ctx.empty), placeholder))),
        ],
        child: FocusableNode(
          onHover: isHovered.set,
          focusNode: focusNode,
          child: CallbackActions(
            actions: [ActOn<ReplaceParentIntent>((intent) => expr.set(intent.expr()))],
            child: ReaderWidget(
              ctx: ctx,
              builder: (_, ctx) => Container(
                decoration: BoxDecoration(
                  border:
                      Option.isPresent(typeError.read(ctx)) ? Border.all(color: Colors.red) : null,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

@reader
Widget _constructEditor(Ctx ctx, {required Cursor<Object> exprData, String suffix = ''}) {
  final typeDef = ctx.getType(exprData[Construct.dataTypeID][Type.IDID].read(ctx) as ID);

  return Inset(
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
}

@reader
Widget _fnAppEditor(
  BuildContext context,
  Ctx ctx, {
  required Cursor<Object> fnApp,
  String suffix = '',
}) {
  bool isWords(GetCursor<Object> expr) {
    final exprType = expr[Expr.implID][Expr.dataTypeID].read(ctx);
    if (exprType == Var.type) return true;
    if (exprType != RecordAccess.type) return false;
    return isWords(expr[Expr.dataID][RecordAccess.targetID]);
  }

  if (isWords(fnApp[FnApp.fnID])) {
    Widget argEditor = ExprEditor(ctx, fnApp[FnApp.argID]);
    var surrounder = paren;
    if (fnApp[FnApp.argID][Expr.implID][Expr.dataTypeID].read(ctx) == Construct.type) {
      final constructData = fnApp[FnApp.argID][Expr.dataID];
      final typeDef = ctx.getType(constructData[Construct.dataTypeID][Type.IDID].read(ctx) as ID);
      if (TypeDef.id(typeDef).contains(TypeDef.typeArgsID)) {
        argEditor = DataTreeEditor(
          ctx,
          TypeDef.tree(typeDef),
          constructData[Construct.treeID],
          ExprEditor.new,
        );
        surrounder = angle;
      }
    }
    return Inset(
      prefix: Text.rich(TextSpan(children: [
        AlignedWidgetSpan(ExprEditor(ctx, fnApp[FnApp.fnID])),
        TextSpan(text: surrounder.open),
      ])),
      contents: [argEditor],
      suffix: Text('${surrounder.close}$suffix'),
    );
  } else {
    return Inset(
      prefix: const Text('apply('),
      contents: [
        ExprEditor(ctx, fnApp[FnApp.fnID], suffix: ', '),
        ExprEditor(ctx, fnApp[FnApp.argID]),
      ],
      suffix: Text(')$suffix'),
    );
  }
}

@reader
Widget _placeholderEditor(
  BuildContext context,
  Ctx ctx, {
  required Cursor<Object> expr,
  required FocusNode focusNode,
  String suffix = '',
}) {
  return Text.rich(TextSpan(children: [
    AlignedWidgetSpan(GenericPlaceholder(
      ctx,
      focusNode: focusNode,
      entries: useComputed(
        ctx,
        (ctx) => reified.Vec(
          ctx.getBindings.expand((binding) {
            final bindingTypeLit = Result.cases(
              Binding.valueType(ctx, binding),
              error: (_) => null,
              ok: (bindingType) => Expr.dataType(bindingType) == Literal.type
                  ? Literal.getValue(Expr.data(bindingType))
                  : null,
            );
            if (bindingTypeLit != null && bindingTypeLit == TypeDef.type) {
              return Option.cases(
                Binding.value(ctx, binding),
                none: () => <PlaceholderEntry>[],
                some: (value) => [
                  PlaceholderEntry(
                    name: '${TypeTree.name(TypeDef.tree(value))}.mk(...)',
                    onPressed: () => expr.set(Construct.mk(
                      TypeDef.asType(value),
                      TypeTree.instantiate(TypeDef.tree(value), placeholder),
                    )),
                  ),
                ],
              );
            } else if (bindingTypeLit != null && Type.id(bindingTypeLit) == Fn.typeDefID) {
              final isTypeConstructor = TypeDef.isTypeConstructorID(Binding.id(binding));
              final surround = isTypeConstructor ? angle : paren;
              return [
                PlaceholderEntry(
                  name: '${Binding.name(ctx, binding)}${surround.apply("...")}',
                  onPressed: () {
                    Object innerExpr = placeholder;
                    if (isTypeConstructor) {
                      final argType = Type.memberEquals(bindingTypeLit, [Fn.argTypeID]);
                      final argTypeDef = ctx.getType(Type.id(argType));
                      innerExpr = Construct.mk(
                        argType,
                        TypeTree.instantiate(TypeDef.tree(argTypeDef), placeholder),
                      );
                    }
                    expr.set(FnApp.mk(Var.mk(Binding.id(binding)), innerExpr));
                  },
                ),
              ];
            } else {
              return [
                PlaceholderEntry(
                  name: Binding.name(ctx, binding),
                  detailedName: (ctx) {
                    final typeString = Result.cases(
                      Binding.valueType(ctx, binding),
                      ok: (typeExpr) => palPrint(ctx, Expr.type, typeExpr),
                      error: (_) => '???',
                    );
                    return '${Binding.name(ctx, binding)}: $typeString';
                  },
                  onPressed: () => expr.set(Var.mk(Binding.id(binding))),
                ),
              ];
            }
          }).toList(),
        ),
        keys: [ctx],
      ),
      onSubmitted: (currentText) {
        final tryNum = num.tryParse(currentText);
        if (tryNum != null) {
          expr.set(Literal.mk(number, tryNum));
        } else if (currentText.startsWith("'") && currentText.endsWith("'")) {
          final tryString = currentText.substring(1, currentText.length - 1);
          if (!tryString.contains("'")) {
            expr.set(Literal.mk(text, tryString));
          }
        } else if (currentText == '\\') {
          expr.set(
            FnExpr.pal(
              argID: ID.mk(),
              argName: 'arg',
              argType: placeholder,
              returnType: placeholder,
              body: placeholder,
            ),
          );
        } else if (currentText == '\\t') {
          expr.set(
            FnTypeExpr.mk(
              argID: ID.mk(),
              argName: 'arg',
              argType: placeholder,
              returnType: placeholder,
            ),
          );
        } else if (currentText == '[') {
          expr.set(List.mkExpr(placeholder, const []));
        } else if (currentText == '{') {
          expr.set(Map.mkExpr(placeholder, placeholder, const []));
        }
      },
    )),
    TextSpan(text: suffix),
  ]));
}

@reader
Widget _dotPlaceholderEditor(
  BuildContext context,
  Ctx ctx, {
  required Cursor<Object> expr,
  String suffix = '',
}) {
  final Cursor<Object> exprData = expr[Expr.dataID];
  final argType = useComputed(
    ctx,
    (ctx) {
      return Result.flatMap(
        typeCheck(ctx, exprData[DotPlaceholder.prefixID].read(ctx)),
        (typeExpr) {
          if (Expr.dataType(typeExpr) != Literal.type) return Result.mkErr('');

          final typeDef = ctx.getType(Type.id(Literal.getValue(Expr.data(typeExpr))));
          return TypeTree.treeCases(
            TypeDef.tree(typeDef),
            union: (_) => Result.mkErr(''),
            leaf: (_) => Result.mkErr(''),
            record: (record) => Result.mkOk(reified.Vec([
              ...record.entries.expand(
                (e) => [
                  if (!TypeDef.comptime(typeDef).contains(e.key))
                    PlaceholderEntry(
                      name: TypeTree.name(e.value),
                      onPressed: () => expr.set(
                        RecordAccess.mk(exprData[DotPlaceholder.prefixID].read(Ctx.empty), e.key),
                      ),
                    )
                ],
              )
            ])),
          );
        },
      );
    },
    keys: [exprData],
    compare: true,
  );
  return Text.rich(TextSpan(children: [
    AlignedWidgetSpan(ExprEditor(ctx, exprData[DotPlaceholder.prefixID])),
    const TextSpan(text: '.'),
    AlignedWidgetSpan(ReaderWidget(
      ctx: ctx,
      builder: (_, ctx) {
        if (argType[Result.valueID][UnionTag.tagID].read(ctx) as ID == Result.errorID) {
          return const Text('unknown');
        } else {
          return GenericPlaceholder(
            ctx,
            entries:
                argType[Result.valueID][UnionTag.valueID].cast<reified.Vec<PlaceholderEntry>>(),
          );
        }
      },
    )),
    TextSpan(text: suffix),
  ]));
}

@reader
Widget _genericPlaceholder(
  BuildContext context,
  Ctx ctx, {
  GetCursor<reified.Vec<PlaceholderEntry>> entries = const GetCursor(reified.Vec()),
  void Function(String)? onSubmitted,
  FocusNode? focusNode,
}) {
  final inputText = useCursor('');
  focusNode = focusNode ?? useMemoized(() => FocusNode(), [focusNode == null]);
  final isOpen = useCursor(focusNode!.hasPrimaryFocus);

  return Focus(
    skipTraversal: true,
    onFocusChange: isOpen.set,
    child: DeferredDropdown(
      isOpen: isOpen,
      closeOnExit: false,
      dropdown: Container(
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 500),
        child: ReaderWidget(
          ctx: ctx,
          builder: (_, ctx) {
            final filteredEntries = useComputed(
              ctx,
              (ctx) => entries.read(ctx).expand(
                (entry) {
                  return [
                    if (entry.name.toLowerCase().startsWith(inputText.read(ctx).toLowerCase()))
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: entry.onPressed,
                          child: Text(
                            entry.detailedName != null ? entry.detailedName!(ctx) : entry.name,
                          ),
                        ),
                      )
                  ];
                },
              ).toList(),
              keys: [entries],
            );
            return ListView(
              shrinkWrap: true,
              children: filteredEntries.read(ctx),
            );
          },
        ),
      ),
      child: Focus(
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (onSubmitted != null) onSubmitted(inputText.read(Ctx.empty));
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text.rich(TextSpan(children: [
            AlignedWidgetSpan(
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 40),
                  child: BoundTextFormField(
                    inputText,
                    ctx: ctx,
                    style: Theme.of(context).textTheme.bodyMedium,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.only(left: 2, top: 4, bottom: 4),
                    ),
                  ),
                ),
              ),
            ),
          ])),
        ),
      ),
    ),
  );
}

class PlaceholderEntry {
  final String name;
  final void Function() onPressed;
  final String Function(Ctx)? detailedName;

  PlaceholderEntry({required this.name, required this.onPressed, this.detailedName});
}

const palShortcuts = {
  SingleActivator(LogicalKeyboardKey.add, shift: true): AddBelowIntent(),
  SingleActivator(LogicalKeyboardKey.keyO): AddWithinIntent(),
  SingleActivator(LogicalKeyboardKey.delete): DeleteIntent(),
  SingleActivator(LogicalKeyboardKey.backspace): DeleteIntent(),
  SingleActivator(LogicalKeyboardKey.keyK, shift: true): ShiftUpIntent(),
  SingleActivator(LogicalKeyboardKey.keyJ, shift: true): ShiftDownIntent(),
  SingleActivator(LogicalKeyboardKey.period): AddDotIntent(),
  SingleActivator(LogicalKeyboardKey.digit9, shift: true): AddFnAppIntent(),
  SingleActivator(LogicalKeyboardKey.keyC): ChangeKindIntent(),
  SingleActivator(LogicalKeyboardKey.keyI): CopyIDIntent(),
};

class AddBelowIntent extends Intent {
  const AddBelowIntent();
}

class AddWithinIntent extends Intent {
  const AddWithinIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

class ShiftUpIntent extends Intent {
  const ShiftUpIntent();
}

class ShiftDownIntent extends Intent {
  const ShiftDownIntent();
}

class AddDotIntent extends Intent {
  const AddDotIntent();
}

class AddFnAppIntent extends Intent {
  const AddFnAppIntent();
}

class ChangeKindIntent extends Intent {
  const ChangeKindIntent();
}

class CopyIDIntent extends Intent {
  const CopyIDIntent();
}

class ReplaceParentIntent extends Intent {
  final Object Function() expr;

  const ReplaceParentIntent(this.expr);
}

void copyID(ID id) =>
    Clipboard.setData(ClipboardData(text: "ID.constant(id: '${id.id}', hashCode: ${id.hashCode})"));
void copyDartFn(ID id) => Clipboard.setData(ClipboardData(text: "@DartFn('${id.id}')"));

const _myBoxShadow = BoxShadow(blurRadius: 8, color: Colors.grey, blurStyle: BlurStyle.outer);

class CallbackActions extends StatelessWidget {
  final dart.List<ActOn> actions;
  final Widget child;

  const CallbackActions({super.key, required this.actions, required this.child});

  @override
  Widget build(BuildContext context) {
    return Actions(actions: dart.Map.fromEntries(actions.map((a) => a.asAction)), child: child);
  }
}

class ActOn<T extends Intent> {
  final void Function(T) callback;

  const ActOn(this.callback);

  MapEntry<dart.Type, Action> get asAction => MapEntry(T, CallbackAction<T>(onInvoke: callback));
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

final ButtonStyle smallButtonStyle = ButtonStyle(
  padding: MaterialStateProperty.all(EdgeInsetsDirectional.zero),
  minimumSize: MaterialStateProperty.all(Size.zero),
);

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
          style: Theme.of(context).textTheme.bodyMedium,
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
            id: ID.mk(),
            name: 'unnamed',
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
          onPressed: () => addDefinition(TypeDef.mkDef(TypeDef.unit('unnamed', id: ID.mk()))),
          child: const Text('Add Type Definition'),
        ),
        MySimpleDialogOption(
          onPressed: () => addDefinition(InterfaceDef.mkDef(InterfaceDef.record(
            'unnamed',
            {},
            id: ID.mk(),
          ))),
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
        if (Binding.valueType(ctx, b) == Result.mkOk(Type.lit(InterfaceDef.type)))
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

class Surrounder {
  final String open;
  final String close;

  const Surrounder(this.open, this.close);
  const Surrounder.same(String openClose)
      : open = openClose,
        close = openClose;

  String apply(String string) => '$open$string$close';
}

const paren = Surrounder('(', ')');
const angle = Surrounder('<', '>');
const bracket = Surrounder('[', ']');
const brace = Surrounder('{', '}');

abstract class Placeholder extends Expr {
  static final typeDef = TypeDef.unit(
    'Placeholder',
    id: const ID.constant(id: '9832bacd-1b55-494a-8db9-f7c55cd5078b', hashCode: 108872934),
  );
  static final type = TypeDef.asType(typeDef);

  static const exprImplID =
      ID.constant(id: '0086f89e-7113-4f6c-950a-c2d92d481681', hashCode: 312213190);
  static final exprImpl = Expr.mkImpl(
    dataType: type,
    argName: 'placeholderData',
    typeCheckBody: palEditorInverseFnMap[_typeCheck]!,
    reduceBody: palEditorInverseFnMap[_reduce]!,
    evalBody: palEditorInverseFnMap[_eval]!,
  );

  @DartFn('b1750fd4-b07f-490b-816f-7933361115e5')
  static Object _typeCheck(Ctx _, Object __) =>
      Result.mkErr('this placeholder needs to be filled in');
  @DartFn('587c85cd-5ce2-4fb0-92a1-3e86086e1154')
  static Object _reduce(Ctx _, Object __) => throw Exception("don't reduce a placeholder u fool!");

  @DartFn('d695423c-c03f-4f9f-beb6-0d615eb938d9')
  static Object _eval(Ctx _, Object __) => throw Exception("don't evaluate a placeholder u fool!");
}

final placeholder = Expr.mk(
  data: const Dict(),
  impl: Placeholder.exprImpl,
);

abstract class DotPlaceholder extends Expr {
  static const prefixID =
      ID.constant(id: 'a87adbe6-0356-4e54-bf86-4015e35149e2', hashCode: 514623045, label: 'prefix');
  static final typeDef = TypeDef.record(
      'DotPlaceholder', {prefixID: TypeTree.mk('prefix', Expr.type)},
      id: const ID.constant(id: '4dce3b99-74e3-4cbc-963b-1a4d2f83525a', hashCode: 457215010));
  static final type = TypeDef.asType(typeDef);

  static const exprImplID =
      ID.constant(id: '928ed976-8105-4a7c-9183-ba0e8e8750ec', hashCode: 272503713);
  static final exprImpl = Expr.mkImpl(
    dataType: type,
    argName: 'placeholderData',
    typeCheckBody: palEditorInverseFnMap[_typeCheck]!,
    reduceBody: palEditorInverseFnMap[_reduce]!,
    evalBody: palEditorInverseFnMap[_eval]!,
  );

  static Object mk(Object expr) => Expr.mk(impl: exprImpl, data: Dict({prefixID: expr}));

  @DartFn('b1750fd4-b07e-490b-816f-7933361115e5')
  static Object _typeCheck(Ctx _, Object __) =>
      Result.mkErr('this placeholder needs to be filled in');

  @DartFn('587c85cd-5ce6-4fb0-92a1-3e86086e1154')
  static Object _reduce(Ctx _, Object __) => throw Exception("don't reduce a placeholder u fool!");

  @DartFn('d695423c-c03a-4f9f-beb6-0d615eb938d9')
  static Object _eval(Ctx _, Object __) => throw Exception("don't evaluate a placeholder u fool!");
}

abstract class Migration {
  const Migration();

  T doMigrate<T>(T obj);
  T doUnmigrate<T>(T obj);

  T migrate<T>(T obj) => _recursiveMigrate(obj, doMigrate);
  T unmigrate<T>(T obj) => _recursiveMigrate(obj, doUnmigrate);
  T _recursiveMigrate<T>(T object, T1 Function<T1>(T1 obj) migrator) {
    if (object is Dict) {
      return migrator(object.mapValues((k, v) => _recursiveMigrate(v, migrator)) as T);
    } else if (object is Vec) {
      return migrator(object.map((v) => _recursiveMigrate(v, migrator)) as T);
    } else {
      return migrator(object);
    }
  }

  @override
  String toString() => runtimeType.toString();
}

final migrations = [
  FnReturnTypeConcrete(),
  FixDotPlaceholder(),
  ImplNames(),
  ValueDefNameToFn(),
  WrapListMkExprTypes(),
];

class FnReturnTypeConcrete extends Migration {
  @override
  T doMigrate<T>(T obj) {
    if (obj is! Dict) return obj;
    if (obj.containsKey(Fn.returnTypeID)) {
      final returnType = obj[Fn.returnTypeID].unwrap! as Dict;
      if (returnType.containsKey(TypeTree.treeID)) {
        final cursor = Cursor<Object>(obj);
        cursor[Fn.returnTypeID][TypeTree.treeID][UnionTag.valueID] = Type.lit(Type.type);
        return cursor.read(Ctx.empty) as T;
      }
    } else if (obj.containsKey(Type.IDID)) {
      final props = obj[Type.propertiesID].unwrap! as Dict;
      final cursor = Cursor<Object>(obj);
      if (props.containsKey(Expr.dataID)) {
        for (final indexedProp in Map.mkExprEntries(Expr.data(props)).indexed) {
          if (Pair.first(indexedProp.value) != Literal.mk(ID.type, Fn.returnTypeID)) continue;
          if (Expr.dataType(Pair.second(indexedProp.value)) != Literal.type) {
            if (Literal.getType(Expr.data(Pair.second(indexedProp.value))) != Expr.type) {
              throw UnimplementedError();
            }
          }
          cursor[Type.propertiesID][Expr.dataID][Map.mkEntriesID][List.itemsID]
              .cast<Vec>()[indexedProp.index][Pair.secondID]
              .set(Literal.getValue(Expr.data(Pair.second(indexedProp.value))));
          return cursor.read(Ctx.empty) as T;
        }
        return obj;
      } else if (props.containsKey(Map.entriesID)) {
        final maybeExpr = Map.entries(props)[Fn.returnTypeID];
        if (!maybeExpr.isPresent) return obj;
        final expr = maybeExpr.unwrap!;
        if (Expr.dataType(expr) == Literal.type) {
          cursor[Type.propertiesID][Map.entriesID][Fn.returnTypeID].set(
            Literal.getValue(Expr.data(expr)),
          );
          return cursor.read(Ctx.empty) as T;
        }
      } else if (props.containsKey(TypeTree.treeID)) {
      } else {
        throw UnimplementedError();
      }
    } else if (obj.containsKey(Expr.dataID)) {
      if ((obj[Expr.dataID].unwrap! as Dict).containsKey(TypeTree.treeID)) return obj;
      final cursor = Cursor<Object>(obj);
      if (Expr.dataType(obj) == Literal.type) {
        if (Literal.getType(Expr.data(obj)) == Type.type) {
          final typeValue = Literal.getValue(Expr.data(obj));
          final props = Type.properties(typeValue);
          final maybeExpr = props[Fn.returnTypeID];
          if (!maybeExpr.isPresent) return obj;
          final expr = maybeExpr.unwrap!;
          if (!(expr as Dict).containsKey(Expr.dataID)) return obj;
          if (Expr.dataType(expr) == Literal.type) {
            cursor[Expr.dataID][Literal.valueID][Type.propertiesID][Map.entriesID][Fn.returnTypeID]
                .set(
              Literal.getValue(Expr.data(expr)),
            );
            return cursor.read(Ctx.empty) as T;
          } else {
            return Fn.typeExpr(
              argID: props[Fn.argIDID].unwrap! as ID,
              argType: Literal.mk(Type.type, props[Fn.argTypeID].unwrap!),
              returnType: expr,
            ) as T;
          }
        }
      }
    }
    return obj;
  }

  @override
  T doUnmigrate<T>(T obj) {
    throw UnimplementedError();
  }
}

class FixDotPlaceholder extends Migration {
  @override
  T doMigrate<T>(T obj) {
    if (obj is! Dict) return obj;
    if (!obj.containsKey(DotPlaceholder.prefixID)) return obj;
    return obj.put(
      DotPlaceholder.prefixID,
      TypeTree.mk('prefix', Type.lit(Expr.type)),
    ) as T;
  }

  @override
  T doUnmigrate<T>(T obj) {
    throw UnimplementedError();
  }
}

class ImplNames extends Migration {
  @override
  T doMigrate<T>(T obj) {
    if (obj is! Dict) return obj;
    if (!obj.containsKey(ImplDef.IDID)) return obj;
    if (obj[ImplDef.IDID].unwrap! is ID) {
      return obj.put(
        ImplDef.nameID,
        'unnamed',
      ) as T;
    } else {
      return obj.put(
        ImplDef.nameID,
        TypeTree.mk('name', Type.lit(text)),
      ) as T;
    }
  }

  @override
  T doUnmigrate<T>(T obj) {
    if (obj is! Dict) return obj;
    if (!obj.containsKey(ImplDef.nameID)) return obj;
    return obj.remove(ImplDef.nameID) as T;
  }
}

class ValueDefNameToFn extends Migration {
  @override
  T doMigrate<T>(T obj) {
    if (obj is! Dict) return obj;
    if (!obj.containsKey(ValueDef.nameID)) return obj;
    final nameValue = obj[ValueDef.nameID].unwrap!;
    if (nameValue is String) {
      return obj.put(
        ValueDef.nameID,
        Fn.mk(
          argID: ValueDef.nameArgID,
          argName: '_',
          body: Fn.mkPalBody(Literal.mk(text, nameValue)),
        ),
      ) as T;
    } else if (nameValue is Dict && nameValue.containsKey(TypeTree.treeID)) {
      final cursor = Cursor<Object>(obj);
      cursor[ValueDef.nameID][TypeTree.treeID][UnionTag.valueID].mut(
        (_) => Type.lit(Fn.type(
          argID: ValueDef.nameArgID,
          argType: unit,
          returnType: Type.lit(text),
        )),
      );
      return cursor.read(Ctx.empty) as T;
    } else {
      throw UnimplementedError();
    }
  }

  @override
  T doUnmigrate<T>(T obj) {
    if (obj is! Dict) return obj;
    if (!obj.containsKey(ValueDef.nameID)) return obj;
    final nameValue = obj[ValueDef.nameID].unwrap!;
    if (nameValue is! Dict) throw UnimplementedError();
    if (nameValue.containsKey(Fn.bodyID)) {
      return obj.put(
        ValueDef.nameID,
        GetCursor<Object>(nameValue)[Fn.bodyID][UnionTag.valueID][Expr.dataID][Literal.valueID]
            .read(Ctx.empty) as String,
      ) as T;
    } else if (nameValue.containsKey(TypeTree.treeID)) {
      final cursor = Cursor<Object>(obj);
      cursor[ValueDef.nameID][TypeTree.treeID][UnionTag.valueID].mut((_) => Type.lit(text));
      return cursor.read(Ctx.empty) as T;
    } else {
      throw UnimplementedError();
    }
  }
}

class WrapListMkExprTypes extends Migration {
  @override
  T doMigrate<T>(T obj) {
    if (obj is Dict) {
      final atMkTypeID = obj[List.mkTypeID].unwrap as Dict?;
      if (atMkTypeID != null) {
        if (atMkTypeID.containsKey(Type.IDID)) {
          return obj.put(List.mkTypeID, Type.lit(atMkTypeID)) as T;
        } else if (atMkTypeID.containsKey(TypeTree.treeID)) {
          final cursor = Cursor<Object>(obj);
          cursor[List.mkTypeID][TypeTree.treeID][UnionTag.valueID].mut((_) => Type.lit(Expr.type));
          return cursor.read(Ctx.empty) as T;
        } else {
          throw UnimplementedError();
        }
      }
    }
    return obj;
  }

  @override
  T doUnmigrate<T>(T obj) {
    if (obj is Dict) {
      final atMkTypeID = obj[List.mkTypeID].unwrap as Dict?;
      if (atMkTypeID != null) {
        if (atMkTypeID.containsKey(Expr.implID)) {
          return obj.put(List.mkTypeID, Literal.getValue(atMkTypeID)) as T;
        } else if (atMkTypeID.containsKey(TypeTree.treeID)) {
          final cursor = Cursor<Object>(obj);
          cursor[List.mkTypeID][TypeTree.treeID][UnionTag.valueID].mut((_) => Type.lit(Type.type));
          return cursor.read(Ctx.empty) as T;
        } else {
          throw UnimplementedError();
        }
      }
    }
    return obj;
  }
}
