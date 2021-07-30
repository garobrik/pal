import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'dropdown.g.dart';

@reader_widget
Widget _replacerDropdown({
  required Widget child,
  required Widget Function(BuildContext context, Size replacedSize) dropdownBuilder,
  required ValueNotifier<bool> isOpen,
  FocusNode? dropdownFocus,
}) {
  final globalKey = useRef(GlobalKey()).value;

  return Dropdown(
    childAnchor: Alignment.topLeft,
    dropdownAnchor: Alignment.topLeft,
    isOpen: isOpen,
    dropdown: LayoutBuilder(
      builder: (context, __) => dropdownBuilder(
        context,
        (globalKey.currentContext!.findRenderObject()! as RenderBox).size,
      ),
    ),
    dropdownFocus: dropdownFocus,
    child: Visibility(
      key: globalKey,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      visible: !isOpen.value,
      child: FocusTraversalGroup(
        descendantsAreFocusable: !isOpen.value,
        child: child,
      ),
    ),
  );
}

@reader_widget
Widget _dropdown({
  required Widget child,
  required Widget dropdown,
  required ValueNotifier<bool> isOpen,
  FocusNode? dropdownFocus,
  Offset offset = Offset.zero,
  Alignment childAnchor = Alignment.bottomLeft,
  Alignment dropdownAnchor = Alignment.topLeft,
}) {
  useEffect(
    () {
      final listener = () {
        if (isOpen.value) {
          dropdownFocus?.requestFocus();
        }
      };
      isOpen.addListener(listener);
      return () => isOpen.removeListener(listener);
    },
    [isOpen, dropdownFocus],
  );

  return FollowingInheritedStackEntry(
    isOpen: isOpen,
    childAnchor: childAnchor,
    overlayAnchor: dropdownAnchor,
    offset: offset,
    overlayBuilder: (_) => FocusTraversalGroup(
      child: Focus(
        skipTraversal: true,
        onFocusChange: (isFocused) {
          if (!isFocused) isOpen.value = false;
        },
        child: Material(
          elevation: 3,
          child: dropdown,
        ),
      ),
    ),
    child: child,
  );
}

@reader_widget
Widget _followingInheritedStackEntry(
  BuildContext context, {
  required Widget child,
  required WidgetBuilder overlayBuilder,
  required ValueListenable<bool> isOpen,
  Offset offset = Offset.zero,
  Alignment childAnchor = Alignment.topLeft,
  Alignment overlayAnchor = Alignment.topLeft,
  bool rootStack = true,
}) {
  final layerLink = useRef(LayerLink()).value;

  return InheritedStackEntry(
    isOpen: isOpen,
    overlayBuilder: (_) => CompositedTransformFollower(
      offset: offset,
      targetAnchor: childAnchor,
      followerAnchor: overlayAnchor,
      link: layerLink,
      child: Builder(builder: overlayBuilder),
    ),
    child: CompositedTransformTarget(link: layerLink, child: child),
  );
}

@reader_widget
Widget _inheritedStackEntry(
  BuildContext context, {
  required Widget child,
  required Widget Function(BuildContext) overlayBuilder,
  required ValueListenable<bool> isOpen,
  bool rootStack = true,
}) {
  final dropdownKey = useRef(UniqueKey()).value;

  useEffect(() {
    final entry = _InheritedStackEntryState(
      (_) => Builder(key: dropdownKey, builder: overlayBuilder),
    );

    final listener = () {
      if (isOpen.value) {
        InheritedStack._of(context, rootStack: rootStack).insert(entry);
      } else {
        entry.remove();
      }
    };

    isOpen.addListener(listener);
    scheduleMicrotask(listener);

    return () {
      scheduleMicrotask(() => entry.remove());
      isOpen.removeListener(listener);
    };
  }, [isOpen, child, overlayBuilder]);

  return child;
}

class InheritedStack extends StatefulWidget {
  final Widget child;

  const InheritedStack({Key? key, required this.child}) : super(key: key);

  static _InheritedStackState _of(BuildContext context, {bool rootStack = false}) {
    final result = rootStack
        ? context.findRootAncestorStateOfType<_InheritedStackState>()
        : context.findAncestorStateOfType<_InheritedStackState>();

    assert(result != null, 'Tried to interact with non-existent InheritedStack.');
    return result!;
  }

  @override
  State<StatefulWidget> createState() => _InheritedStackState();
}

class _InheritedStackState extends State<InheritedStack> {
  final stack = <_InheritedStackEntryState>[];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        for (final entry in stack) entry.builder(context),
      ],
    );
  }

  void insert(_InheritedStackEntryState entry, {bool rootStack = false}) {
    setState(() => stack.add(entry));
    entry._remove = () => setState(() => stack.remove(entry));
  }
}

class _InheritedStackEntryState {
  final WidgetBuilder builder;

  Dispose? _remove;

  _InheritedStackEntryState(this.builder);

  void remove() {
    if (_remove != null) {
      _remove!();
    }
  }
}
