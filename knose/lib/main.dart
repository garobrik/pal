import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infra_widgets/deferred_paint.dart';
import 'package:knose/pal.dart' hide number, Literal, Text, text, Type, TypeTree, ID, Expr;
import 'package:knose/src/app_widgets/pal_editor.dart';
import 'package:knose/theme.dart';
import 'package:knose/model.dart' as model;
import 'package:knose/app_widgets.dart';
import 'package:knose/infra_widgets.dart';
import 'package:infra_widgets/focus_trap.dart';
import 'package:knose/shortcuts.dart';

part 'main.g.dart';

void main() {
  runApp(const MyApp());
}

@reader
Widget myApp() {
  return CursorWidget(
    ctx: Ctx.empty,
    create: () => model.baseDB,
    builder: (_, ctx, Cursor<DB> db) => KeyPressedProvider(
      child: DisableBuiltinFocusTrap(
        child: MaterialApp(
          title: 'knose',
          shortcuts: shortcuts,
          actions: actions,
          theme: theme(Colors.grey, Brightness.light),
          onGenerateRoute: (settings) {
            if (settings.name == '/') {
              return MaterialPageRoute<void>(
                builder: (context) {
                  return const Scaffold(
                    body: DeferredPaintTarget(
                      child: TestThingy(Ctx.empty),
                    ),
                  );
                  // return ReaderWidget(
                  //   ctx: Ctx.empty,
                  //   builder: (context, ctx) {
                  //     final bindingID = ID('binding');
                  //     final expr = useCursor(placeholder);
                  //     final binding = useMemoized(
                  //       () => Binding.mk(
                  //         id: bindingID,
                  //         type: Fn.type(argType: number, returnType: number),
                  //         name: 'the function!',
                  //         value: Optional(Expr.data(Fn.from(
                  //           argName: 'numba',
                  //           type: Fn.type(argType: number, returnType: number),
                  //           body: (arg) => arg,
                  //         ))),
                  //       ),
                  //     );
                  //     final testCtx = coreCtx.withBinding(binding);
                  //     return Scaffold(
                  //       body: DeferredPaintTarget(
                  //         child: Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             ExprEditor(testCtx, expr),
                  //             const Divider(),
                  //             ReaderWidget(
                  //               ctx: ctx,
                  //               builder: (_, ctx) {
                  //                 final type = typeCheck(testCtx, expr.read(ctx));
                  //                 return Option.cases(
                  //                   type,
                  //                   some: (type) {
                  //                     final typeDef = testCtx.getType(Type.id(type));
                  //                     return Text(
                  //                       '${TypeTree.name(TypeDef.tree(typeDef))}: ${eval(testCtx, expr.read(ctx))}',
                  //                     );
                  //                   },
                  //                   none: () => const Text('errorr!'),
                  //                 );
                  //               },
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     );
                  //   },
                  // );
                },
              );
            }

            if (settings.name == '/') {
              return generateSearchRoute(ctx.withDB(db));
            }

            final arguments = settings.arguments;
            if (arguments is model.Route) {
              return arguments.cases(
                widgetRoute: (widget) =>
                    generateWidgetRoute(widget.ctx ?? ctx.withDB(db), widget.id),
                searchRoute: (_) => generateSearchRoute(ctx.withDB(db)),
              );
            }
            return null;
          },
        ),
      ),
    ),
  );
}
