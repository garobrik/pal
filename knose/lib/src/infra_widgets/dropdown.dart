import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'dropdown.g.dart';

@reader_widget
Widget _dropdown({
  required Widget Function(void Function() onPressed) childBuilder,
  required Widget Function(FocusNode) dropdownBuilder,
  double minWidth = 200,
  Offset offset = Offset.zero,
  Alignment childAnchor = Alignment.bottomLeft,
  Alignment dropdownAnchor = Alignment.topLeft,
}) {
  final isOpen = useState(false);
  final focusNode = useFocusNode();

  return MyOverlay(
    isOpen: isOpen.value,
    childAnchor: childAnchor,
    overlayAnchor: dropdownAnchor,
    offset: offset,
    overlay: FocusTraversalGroup(
      child: Focus(
        skipTraversal: true,
        onFocusChange: (isFocused) {
          if (!isFocused) isOpen.value = false;
        },
        child: IntrinsicWidth(
          child: Material(
            elevation: 5,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: dropdownBuilder(focusNode),
            ),
          ),
        ),
      ),
    ),
    child: childBuilder(() {
      isOpen.value = !isOpen.value;
      focusNode.requestFocus();
    }),
  );
}

@reader_widget
Widget _myOverlay(
  BuildContext context, {
  required Widget child,
  required Widget overlay,
  required bool isOpen,
  Offset offset = Offset.zero,
  Alignment childAnchor = Alignment.topLeft,
  Alignment overlayAnchor = Alignment.topLeft,
}) {
  final layerLink = useRef(LayerLink()).value;
  final focusLink = useRef(_FocusLink()).value;
  final dropdownKey = useRef(UniqueKey()).value;

  useEffect(() {
    if (isOpen) {
      final entry = _InheritedStackEntry(
        (BuildContext context) => _LinkedFocusFollower(
          key: dropdownKey,
          link: focusLink,
          child: CompositedTransformFollower(
            link: layerLink,
            targetAnchor: childAnchor,
            followerAnchor: overlayAnchor,
            offset: offset,
            child: overlay,
          ),
        ),
      );
      final stackState = InheritedStack._of(context);
      scheduleMicrotask(() {
        stackState.insert(entry);
      });
      return entry.remove;
    }
  }, [isOpen, child, overlay]);

  return _LinkedFocusTarget(
    link: focusLink,
    child: CompositedTransformTarget(link: layerLink, child: child),
  );
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

class _InheritedStackEntry {
  final WidgetBuilder builder;

  Dispose? _remove;

  _InheritedStackEntry(this.builder);

  void remove() {
    if (_remove != null) {
      _remove!();
    }
  }
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
    entry._remove = () => scheduleMicrotask(() => setState(() => stack.remove(entry)));
  }
}

@reader_widget
Widget _overlayFocusTraversalFix(
  BuildContext context, {
  required Widget child,
}) {
  return FocusTraversalGroup(
    policy: _LinkedFocusTraversalPolicy(
      FocusTraversalGroup.maybeOf(context) ?? ReadingOrderTraversalPolicy(),
    ),
    child: child,
  );
}

class _LinkedFocusTraversalPolicy extends FocusTraversalPolicy
    with DirectionalFocusTraversalPolicyMixin {
  final FocusTraversalPolicy defaultPolicy;

  _LinkedFocusTraversalPolicy(this.defaultPolicy);

  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    print('im doin it!');
    final Iterable<FocusNode> sortedDescendants =
        defaultPolicy.sortDescendants(descendants, currentNode);
    final followers = <_FocusLink, List<FocusNode>>{};
    final notFollowers = <FocusNode>[];
    for (final FocusNode node in sortedDescendants) {
      final _FocusLink? followed = _LinkedFocusFollower.maybeOf(node.context!);
      if (followed != null) {
        followers.putIfAbsent(followed, () => []).add(node);
      } else {
        notFollowers.add(node);
      }
    }

    final result = <FocusNode>[];
    final targets = <_FocusLink>[];
    for (int index = 0; index < notFollowers.length;) {
      final node = notFollowers[index];
      result.add(node);
      if (node is _LinkedFocusNode) {
        print('found uuu');
        targets.add(node.link);

        for (index++; index < notFollowers.length; index++) {
          final maybeSubNode = notFollowers[index];
          final link = _LinkedFocusTargetInherited.maybeOf(maybeSubNode.context!);
          if (link != node.link) break;
          result.add(maybeSubNode);
        }

        result.addAll(followers.putIfAbsent(node.link, () => []));
        followers.remove(node.link);
      } else {
        index++;
      }
    }

    assert(followers.isEmpty, '_LinkedFocusFollower without target');

    return result;
  }
}

class _FocusLink {}

class _LinkedFocusNode extends FocusNode {
  final _FocusLink link;
  _LinkedFocusNode(this.link) : super(canRequestFocus: false, skipTraversal: true);
}

class _LinkedFocusTarget extends HookWidget {
  final _FocusLink link;
  final Widget child;

  const _LinkedFocusTarget({Key? key, required this.link, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final focusNode = useMemoized(() => _LinkedFocusNode(link), [link]);

    return Focus(
      skipTraversal: true,
      focusNode: focusNode,
      child: _LinkedFocusTargetInherited(
        link: link,
        child: child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<_FocusLink>('link', link));
  }
}

class _LinkedFocusTargetInherited extends InheritedWidget {
  const _LinkedFocusTargetInherited({Key? key, required this.link, required Widget child})
      : super(key: key, child: child);

  final _FocusLink link;

  static _FocusLink? maybeOf(BuildContext context) {
    final _LinkedFocusTargetInherited? follower = context
        .getElementForInheritedWidgetOfExactType<_LinkedFocusTargetInherited>()
        ?.widget as _LinkedFocusTargetInherited?;
    return follower?.link;
  }

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<_FocusLink>('link', link));
  }
}

class _LinkedFocusFollower extends InheritedWidget {
  const _LinkedFocusFollower({Key? key, required this.link, required Widget child})
      : super(key: key, child: child);

  final _FocusLink link;

  static _FocusLink? maybeOf(BuildContext context) {
    final _LinkedFocusFollower? follower = context
        .getElementForInheritedWidgetOfExactType<_LinkedFocusFollower>()
        ?.widget as _LinkedFocusFollower?;
    return follower?.link;
  }

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<_FocusLink>('link', link));
  }
}

@reader_widget
Widget _dropdownPortal({
  required Widget child,
  required Widget dropdown,
  Alignment? childAnchor,
  Alignment? dropdownAnchor,
  ButtonStyle? style,
  double? width,
}) {
  final isOpen = useState(false);
  final focusNode = useFocusNode();

  return FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: PortalEntry(
      visible: isOpen.value,
      childAnchor: childAnchor,
      portalAnchor: dropdownAnchor,
      portal: FocusTraversalOrder(
        order: NumericFocusOrder(2),
        child: FocusTraversalGroup(
          child: Focus(
            skipTraversal: true,
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                isOpen.value = false;
              }
            },
            child: Material(
              elevation: 4.0,
              borderRadius: const BorderRadius.all(Radius.circular(3.0)),
              child: width == null
                  ? IntrinsicWidth(child: dropdown)
                  : ConstrainedBox(constraints: BoxConstraints.tightFor(width: width)),
            ),
          ),
        ),
      ),
      child: FocusTraversalOrder(
        order: NumericFocusOrder(1),
        child: TextButton(
          focusNode: focusNode,
          style: style,
          onPressed: () {
            isOpen.value = !isOpen.value;
            if (isOpen.value == true) {
              SchedulerBinding.instance?.addPostFrameCallback((_) => focusNode.nextFocus());
            }
          },
          child: child,
        ),
      ),
    ),
  );
}
