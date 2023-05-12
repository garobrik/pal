import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infra_widgets/hierarchical_traversal.dart';
import 'package:infra_widgets/non_text_editing_shortcut_manager.dart';

class FocusableNode extends HookWidget {
  final FocusNode? focusNode;
  final void Function(bool)? onHover;
  final Widget child;

  const FocusableNode({this.focusNode, this.onHover, required this.child, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final wrapperFocusNode = useMemoized(() => focusNode ?? FocusNode(), [focusNode == null]);

    return Shortcuts.manager(
      manager: NonTextEditingShortcutManager(
        shortcuts: {
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
            final descendants = wrapperFocusNode.hierarchicalTraversableDescendants;
            if (descendants.isNotEmpty) {
              descendants.first.requestFocus();
            }
          }),
        },
      ),
      child: FocusableActionDetector(
        focusNode: wrapperFocusNode,
        onShowHoverHighlight: onHover,
        child: Builder(
          builder: (context) => Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              boxShadow: [if (Focus.of(context).hasPrimaryFocus) _myBoxShadow],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

const _myBoxShadow = BoxShadow(blurRadius: 8, color: Colors.grey, blurStyle: BlurStyle.outer);
