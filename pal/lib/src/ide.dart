// import 'package:flutter/material.dart' hide Placeholder;
// import 'package:flutter/services.dart';
// import 'package:flutter_hooks/flutter_hooks.dart';
// import 'package:infra_widgets/focusable_node.dart';
// import 'package:infra_widgets/hierarchical_traversal.dart';
// import 'package:infra_widgets/inherited_value.dart';
// import 'package:infra_widgets/inset.dart';
// import 'package:infra_widgets/non_text_editing_shortcut_manager.dart';
// import 'package:infra_widgets/inline_spans.dart';
// import 'package:pal/src/lang.dart';

// class ExprClipboard {
//   Expr? expr;
// }

// class IDEScaffold extends StatelessWidget {
//   final Widget child;

//   const IDEScaffold(this.child, {super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Shortcuts.manager(
//         manager: NonTextEditingShortcutManager(shortcuts: palShortcuts),
//         child: FocusTraversalGroup(
//           policy: HierarchicalOrderTraversalPolicy(),
//           child: InheritedValue(value: ExprClipboard(), child: child),
//         ),
//       ),
//     );
//   }
// }

// class ExprEditor extends HookWidget {
//   final void Function(Expr) onChanged;
//   final Expr expr;

//   const ExprEditor({required this.onChanged, required this.expr, super.key});

//   @override
//   Widget build(BuildContext context) {
//     final expr = this.expr;
//     late final Widget child;

//     if (expr is Literal) {
//       child = Text(expr.val.toString());
//     } else if (expr is Var) {
//       child = Text(expr.id.toString());
//     } else if (expr is Placeholder) {
//       return InlineTextField(
//         text: '',
//         onFieldSubmitted: (text) {
//           if (text == 'Type') {
//             onChanged(Type.expr);
//           } else if (text == '\\') {
//             onChanged(const FnDef('', Placeholder.expr, Placeholder.expr, Placeholder.expr));
//           } else if (text == '\\t') {
//             onChanged(const FnTypeExpr('', Placeholder.expr, Placeholder.expr));
//           } else if (text == '(') {
//             onChanged(const FnApp(Placeholder.expr, Placeholder.expr));
//           } else {
//             onChanged(Var(text));
//           }
//         },
//       );
//     } else if (expr is FnApp) {
//       final surround = expr.fn is FnDef;
//       child = Inset(
//         prefix: Text.rich(TextSpan(children: [
//           if (surround) const TextSpan(text: '('),
//           AlignedWidgetSpan(ExprEditor(
//             onChanged: (newFn) => onChanged(FnApp(newFn, expr.arg)),
//             expr: expr.fn,
//           )),
//           if (surround) const TextSpan(text: ')'),
//           const TextSpan(text: '('),
//         ])),
//         contents: [
//           ExprEditor(
//             onChanged: (newArg) => onChanged(FnApp(expr.fn, newArg)),
//             expr: expr.arg,
//           ),
//         ],
//         suffix: const Text(')'),
//       );
//     } else if (expr is FnDef) {
//       child = Inset(
//         prefix: Text.rich(TextSpan(children: [
//           const TextSpan(text: '('),
//           InlineTextSpan(
//             onChanged: (newID) => onChanged(
//               FnDef(newID, expr.argType, expr.returnType, expr.body),
//             ),
//             text: expr.argID,
//           ),
//           const TextSpan(text: ': '),
//           AlignedWidgetSpan(ExprEditor(
//             onChanged: (newArgType) => onChanged(
//               FnDef(expr.argID, newArgType, expr.returnType, expr.body),
//             ),
//             expr: expr.argType,
//           )),
//           const TextSpan(text: '): '),
//           AlignedWidgetSpan(ExprEditor(
//             onChanged: (newReturnType) => onChanged(
//               FnDef(expr.argID, expr.argType, newReturnType, expr.body),
//             ),
//             expr: expr.returnType,
//           )),
//           const TextSpan(text: ' => '),
//         ])),
//         contents: [
//           ExprEditor(
//             onChanged: (newBody) => onChanged(
//               FnDef(expr.argID, expr.argType, expr.returnType, newBody),
//             ),
//             expr: expr.body,
//           )
//         ],
//       );
//     } else if (expr is FnTypeExpr) {
//       child = Inset(
//         prefix: Text.rich(TextSpan(children: [
//           const TextSpan(text: '('),
//           InlineTextSpan(
//             onChanged: (newID) => onChanged(
//               FnTypeExpr(newID, expr.argType, expr.returnType),
//             ),
//             text: expr.argID,
//           ),
//           const TextSpan(text: ': '),
//           AlignedWidgetSpan(ExprEditor(
//             onChanged: (newArgType) => onChanged(
//               FnTypeExpr(expr.argID, newArgType, expr.returnType),
//             ),
//             expr: expr.argType,
//           )),
//           const TextSpan(text: ' -> '),
//         ])),
//         contents: [
//           ExprEditor(
//             onChanged: (newReturnType) => onChanged(
//               FnTypeExpr(expr.argID, expr.argType, newReturnType),
//             ),
//             expr: expr.returnType,
//           ),
//         ],
//         suffix: const Text(')'),
//       );
//     }

//     return Shortcuts(
//       shortcuts: {
//         const SingleActivator(LogicalKeyboardKey.keyR, shift: true): ReplaceParentIntent(() => expr)
//       },
//       child: Actions(
//         actions: {
//           DeleteIntent: CallbackAction(onInvoke: (_) => onChanged(Placeholder.expr)),
//           WrapAsFnIntent: CallbackAction(onInvoke: (_) => onChanged(FnApp(expr, Placeholder.expr))),
//           WrapAsArgIntent:
//               CallbackAction(onInvoke: (_) => onChanged(FnApp(Placeholder.expr, expr))),
//           CopyIntent: CallbackAction(
//             onInvoke: (_) => InheritedValue.of<ExprClipboard>(context).expr = expr,
//           ),
//           PasteIntent: CallbackAction(
//             onInvoke: (_) {
//               final newExpr = InheritedValue.of<ExprClipboard>(context).expr;
//               return newExpr == null ? null : onChanged(newExpr);
//             },
//           ),
//           PasteCopyIntent: CallbackAction(
//             onInvoke: (_) {
//               final newExpr = InheritedValue.of<ExprClipboard>(context).expr;
//               InheritedValue.of<ExprClipboard>(context).expr = expr;
//               return newExpr == null ? null : onChanged(newExpr);
//             },
//           ),
//         },
//         child: FocusableNode(
//           child: Actions(
//             actions: {
//               ReplaceParentIntent<Expr>: CallbackAction<ReplaceParentIntent<Expr>>(
//                 onInvoke: (intent) {
//                   onChanged(intent.replaceWith());
//                   return null;
//                 },
//               ),
//             },
//             child: child,
//           ),
//         ),
//       ),
//     );
//   }
// }

// const palShortcuts = {
//   SingleActivator(LogicalKeyboardKey.add, shift: true): AddBelowIntent(),
//   SingleActivator(LogicalKeyboardKey.keyO): AddWithinIntent(),
//   SingleActivator(LogicalKeyboardKey.delete): DeleteIntent(),
//   SingleActivator(LogicalKeyboardKey.backspace): DeleteIntent(),
//   SingleActivator(LogicalKeyboardKey.keyK, shift: true): ShiftUpIntent(),
//   SingleActivator(LogicalKeyboardKey.keyJ, shift: true): ShiftDownIntent(),
//   SingleActivator(LogicalKeyboardKey.period): AddDotIntent(),
//   SingleActivator(LogicalKeyboardKey.digit9, shift: true): WrapAsArgIntent(),
//   SingleActivator(LogicalKeyboardKey.digit0, shift: true): WrapAsFnIntent(),
//   SingleActivator(LogicalKeyboardKey.keyC): ChangeKindIntent(),
//   SingleActivator(LogicalKeyboardKey.keyI): CopyIDIntent(),
//   SingleActivator(LogicalKeyboardKey.keyY): CopyIntent(),
//   SingleActivator(LogicalKeyboardKey.keyP): PasteIntent(),
//   SingleActivator(LogicalKeyboardKey.keyP, shift: true): PasteCopyIntent(),
// };

// class AddBelowIntent extends Intent {
//   const AddBelowIntent();
// }

// class AddWithinIntent extends Intent {
//   const AddWithinIntent();
// }

// class DeleteIntent extends Intent {
//   const DeleteIntent();
// }

// class ShiftUpIntent extends Intent {
//   const ShiftUpIntent();
// }

// class ShiftDownIntent extends Intent {
//   const ShiftDownIntent();
// }

// class AddDotIntent extends Intent {
//   const AddDotIntent();
// }

// class AddFnAppIntent extends Intent {
//   const AddFnAppIntent();
// }

// class ChangeKindIntent extends Intent {
//   const ChangeKindIntent();
// }

// class CopyIDIntent extends Intent {
//   const CopyIDIntent();
// }

// class WrapAsFnIntent extends Intent {
//   const WrapAsFnIntent();
// }

// class WrapAsArgIntent extends Intent {
//   const WrapAsArgIntent();
// }

// class CopyIntent extends Intent {
//   const CopyIntent();
// }

// class PasteIntent extends Intent {
//   const PasteIntent();
// }

// class PasteCopyIntent extends Intent {
//   const PasteCopyIntent();
// }

// class ReplaceParentIntent<T> extends Intent {
//   final T Function() replaceWith;

//   const ReplaceParentIntent(this.replaceWith);
// }
