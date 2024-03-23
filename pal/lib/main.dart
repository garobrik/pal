// import 'dart:io';

// import 'package:flutter/material.dart' hide Placeholder;
// import 'package:pal/src/ide.dart';
// import 'package:pal/src/lang.dart';
// import 'package:pal/src/theme.dart';

// void main() {
//   runApp(const Pal());
// }

// class Pal extends StatelessWidget {
//   const Pal({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) => MaterialApp(
//         title: 'pal',
//         theme: theme(Colors.grey, Brightness.light),
//         home: const SingleExprEditor(),
//       );
// }

// class SingleExprEditor extends StatefulWidget {
//   const SingleExprEditor({super.key});

//   @override
//   State<StatefulWidget> createState() => SingleExprEditorState();
// }

// class SingleExprEditorState extends State<SingleExprEditor> {
//   late Expr expr;
//   late TypeCheckResult typeResult;
//   late Object? result;

//   SingleExprEditorState() {
//     onChanged(Placeholder.expr, true);
//   }

//   void onChanged(Expr newExpr, [bool ctor = false]) {
//     impl() {
//       expr = newExpr;
//       typeResult = typeCheck(TypeCtx.empty, expr);
//       result = typeResult.isOk ? eval(BindingCtx.empty, expr) : null;
//     }

//     ctor ? impl() : setState(impl);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final saveDir = Directory('palsrc');
//     final saveFile = File('${saveDir.path}/test.pal');

//     return IDEScaffold(Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             TextButton(
//               onPressed: () => saveFile.writeAsString(expr.serialize),
//               child: const Text('save to file'),
//             ),
//             TextButton(
//               onPressed: () => Expr.parser.parse(saveFile.readAsStringSync()).cases(
//                     ok: (ok) => onChanged(ok.result),
//                     fail: (fail) => throw Exception('couldn\'t parse file because ${fail.reason}'),
//                   ),
//               child: const Text('load from file'),
//             )
//           ],
//         ),
//         const Divider(),
//         Text(
//           typeResult.isOk ? typeResult.assertOk.type.toString() : typeResult.assertFailure.reason,
//         ),
//         const Divider(),
//         Text(result.toString()),
//         const Divider(),
//         ExprEditor(
//           onChanged: onChanged,
//           expr: expr,
//         )
//       ],
//     ));
//   }
// }
