import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';

part 'dropdown.g.dart';

@reader_widget
Widget _deferredDropdown(
  BuildContext context, {
  required Widget child,
  required Widget dropdown,
  required Cursor<bool> isOpen,
  FocusNode? dropdownFocus,
  Offset offset = Offset.zero,
  Alignment childAnchor = Alignment.bottomLeft,
  Alignment dropdownAnchor = Alignment.topLeft,
}) {
  useEffect(() {
    if (dropdownFocus == null) return null;

    return isOpen.listen((wasOpen, isOpen, _) {
      if (isOpen && !wasOpen) {
        dropdownFocus.requestFocus();
      }
    });
  }, [isOpen, dropdownFocus]);

  return FocusTraversalGroup(
    policy: WidgetOrderTraversalPolicy(),
    child: FollowingDeferredPainter(
      isOpen: isOpen,
      childAnchor: childAnchor,
      overlayAnchor: dropdownAnchor,
      offset: offset,
      deferee: Focus(
        onKey: (node, key) {
          if (key.logicalKey == LogicalKeyboardKey.escape) {
            isOpen.set(false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        skipTraversal: true,
        onFocusChange: isOpen.set,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: Colors.grey, blurRadius: 7),
            ],
            color: Theme.of(context).canvasColor,
          ),
          child: dropdown,
        ),
      ),
      child: child,
    ),
  );
}

@reader_widget
Widget _followingDeferredPainter(
  Reader reader,
  BuildContext context, {
  required Widget child,
  required Widget deferee,
  required GetCursor<bool> isOpen,
  Offset offset = Offset.zero,
  Alignment childAnchor = Alignment.topLeft,
  Alignment overlayAnchor = Alignment.topLeft,
}) {
  final link = useRef(LayerLink()).value;

  return Stack(
    fit: StackFit.passthrough,
    children: [
      CompositedTransformTarget(link: link, child: child),
      if (isOpen.read(reader))
        Positioned.fill(
          child: DeferredPainter(
            child: CompositedTransformFollower(
              link: link,
              offset: offset,
              targetAnchor: childAnchor,
              followerAnchor: overlayAnchor,
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: overlayAnchor,
                child: deferee,
              ),
            ),
          ),
        ),
    ],
  );
}

@reader_widget
Widget _replacerDropdown(
  Reader reader, {
  required Widget child,
  required Widget Function(BuildContext context, Size replacedSize) dropdownBuilder,
  required Cursor<bool> isOpen,
  Alignment childAnchor = Alignment.topLeft,
  Alignment dropdownAnchor = Alignment.topLeft,
}) {
  final globalKey = useRef(GlobalKey()).value;

  return Dropdown(
    childAnchor: childAnchor,
    dropdownAnchor: dropdownAnchor,
    isOpen: isOpen,
    dropdown: LayoutBuilder(
      builder: (context, __) => dropdownBuilder(
        context,
        (globalKey.currentContext!.findRenderObject()! as RenderBox).size,
      ),
    ),
    child: Visibility(
      key: globalKey,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      visible: !isOpen.read(reader),
      child: child,
    ),
  );
}

@reader_widget
Widget _dropdown({
  required Widget child,
  required Widget dropdown,
  required Cursor<bool> isOpen,
  Offset offset = Offset.zero,
  Alignment childAnchor = Alignment.bottomLeft,
  Alignment dropdownAnchor = Alignment.topLeft,
}) {
  return FollowingModalRoute(
    isOpen: isOpen,
    childAnchor: childAnchor,
    overlayAnchor: dropdownAnchor,
    offset: offset,
    overlayBuilder: (_) => Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.grey, blurRadius: 7),
        ],
      ),
      child: Material(
        child: dropdown,
      ),
    ),
    child: child,
  );
}

@reader_widget
Widget _followingModalRoute(
  BuildContext context, {
  required Widget child,
  required WidgetBuilder overlayBuilder,
  required Cursor<bool> isOpen,
  Offset offset = Offset.zero,
  Alignment childAnchor = Alignment.topLeft,
  Alignment overlayAnchor = Alignment.topLeft,
}) {
  final layerLink = useMemoized(() => LayerLink());
  final currentlyOpen = useCursor(false);

  final showDropdown = useMemoized(() {
    return () {
      if (!currentlyOpen.read(null)) {
        showDialog<Null>(
          context: context,
          builder: (_) => Center(
            child: CompositedTransformFollower(
              offset: offset,
              targetAnchor: childAnchor,
              followerAnchor: overlayAnchor,
              link: layerLink,
              child: Builder(builder: overlayBuilder),
            ),
          ),
          barrierColor: null,
        ).then(
          (_) {
            isOpen.set(false);
            currentlyOpen.set(false);
          },
        );

        currentlyOpen.set(true);
      }
    };
  }, [overlayBuilder, childAnchor, overlayAnchor, layerLink, offset]);

  useEffect(() {
    if (isOpen.read(null)) {
      scheduleMicrotask(showDropdown);
    }
  });

  useEffect(() {
    return isOpen.listen((_, currentlyOpen, ___) {
      if (currentlyOpen) {
        showDropdown();
      }
    });
  }, [isOpen, showDropdown]);

  return CompositedTransformTarget(link: layerLink, child: child);
}

@reader_widget
Widget _replacerWidget(
  Reader reader, {
  required Widget child,
  required Widget Function(BuildContext context, Size replacedSize) dropdownBuilder,
  required Cursor<bool> isOpen,
  FocusNode? dropdownFocus,
  Alignment childAnchor = Alignment.topLeft,
  Alignment dropdownAnchor = Alignment.topLeft,
  Offset offset = Offset.zero,
}) {
  final globalKey = useRef(GlobalKey()).value;

  return OldDropdown(
    childAnchor: childAnchor,
    dropdownAnchor: dropdownAnchor,
    offset: offset,
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
      visible: !isOpen.read(reader),
      child: FocusTraversalGroup(
        descendantsAreFocusable: !isOpen.read(reader),
        child: child,
      ),
    ),
  );
}

@reader_widget
Widget _oldDropdown(
  BuildContext context, {
  required Widget child,
  required Widget dropdown,
  required Cursor<bool> isOpen,
  FocusNode? dropdownFocus,
  Offset offset = Offset.zero,
  Alignment childAnchor = Alignment.bottomLeft,
  Alignment dropdownAnchor = Alignment.topLeft,
}) {
  final numChildren = Cursor(0);
  useEffect(
    () => isOpen.listen(
      (_, isOpen, ___) {
        if (isOpen) {
          dropdownFocus?.requestFocus();
        }
      },
    ),
    [isOpen, dropdownFocus],
  );

  return DropdownChild(
    child: FollowingInheritedStackEntry(
      isOpen: GetCursor.compute(
        (reader) => isOpen.read(reader) || numChildren.read(reader) > 0,
      ),
      childAnchor: childAnchor,
      overlayAnchor: dropdownAnchor,
      offset: offset,
      overlayBuilder: (_) => _DropdownInheritedWidget(
        numChildren: numChildren,
        child: FocusTraversalGroup(
          child: Focus(
            onKey: (node, key) {
              if (key.logicalKey == LogicalKeyboardKey.escape) {
                isOpen.set(false);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            skipTraversal: true,
            onFocusChange: isOpen.set,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: Colors.grey, blurRadius: 7),
                ],
                color: Theme.of(context).canvasColor,
              ),
              child: dropdown,
            ),
          ),
        ),
      ),
      child: child,
    ),
  );
}

@reader_widget
Widget _followingInheritedStackEntry(
  BuildContext context, {
  required Widget child,
  required WidgetBuilder overlayBuilder,
  required GetCursor<bool> isOpen,
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
  required GetCursor<bool> isOpen,
  bool rootStack = true,
}) {
  final dropdownKey = useRef(UniqueKey()).value;

  useEffect(() {
    final entry = _InheritedStackEntry(
      (_) => Builder(key: dropdownKey, builder: overlayBuilder),
    );

    final listener = () {
      if (isOpen.read(null) && !entry.isEntered) {
        InheritedStack._of(context, rootStack: rootStack).insert(entry);
      } else if (!isOpen.read(null) && entry.isEntered) {
        entry.remove();
      }
    };

    final dispose = isOpen.listen((_, __, ___) => listener());
    scheduleMicrotask(listener);

    return () {
      scheduleMicrotask(() => entry.remove());
      dispose();
    };
  }, [isOpen, overlayBuilder]);

  return child;
}

@reader_widget
Widget _dropdownChild(BuildContext context, {required Widget child}) {
  final inherited = context.dependOnInheritedWidgetOfExactType<_DropdownInheritedWidget>();
  useEffect(
    () {
      inherited?.numChildren.mut((i) => i + 1);
      return () => inherited?.numChildren.mut((i) => i - 1);
    },
    [inherited, inherited?.numChildren],
  );

  return child;
}

class _DropdownInheritedWidget extends InheritedWidget {
  final Cursor<int> numChildren;

  _DropdownInheritedWidget({
    required this.numChildren,
    required Widget child,
    Key? key,
  }) : super(child: child, key: key);

  @override
  bool updateShouldNotify(covariant _DropdownInheritedWidget oldWidget) =>
      this.numChildren != oldWidget.numChildren;
}

class InheritedStack extends StatefulWidget {
  final Widget child;

  const InheritedStack({Key? key, required this.child}) : super(key: key);

  static _InheritedStackState _of(BuildContext context, {bool rootStack = false}) {
    final result = rootStack
        ? context.findRootAncestorStateOfType<_InheritedStackState>()
        : context.findAncestorStateOfType<_InheritedStackState>();

    assert(
      result != null,
      'Tried to interact with non-existent InheritedStack.',
    );
    return result!;
  }

  @override
  State<StatefulWidget> createState() => _InheritedStackState();
}

class _InheritedStackState extends State<InheritedStack> {
  final stack = <_InheritedStackEntry>[];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        for (final entry in stack) entry.builder(context),
      ],
    );
  }

  void insert(_InheritedStackEntry entry, {bool rootStack = false}) {
    setState(() => stack.add(entry));
    entry._remove = () => setState(() => stack.remove(entry));
  }
}

class _InheritedStackEntry {
  final WidgetBuilder builder;

  Dispose? _remove;

  _InheritedStackEntry(this.builder);

  void remove() {
    if (_remove != null) {
      _remove!();
      _remove = null;
    }
  }

  bool get isEntered => _remove != null;
}
