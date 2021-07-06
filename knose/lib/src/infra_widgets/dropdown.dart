import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'dropdown.g.dart';

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
  useEffect(() {
    if (isOpen) {
      final entry = OverlayEntry(
        builder: (context) => CompositedTransformFollower(
          link: layerLink,
          targetAnchor: childAnchor,
          followerAnchor: overlayAnchor,
          offset: offset,
          child: overlay,
        ),
      );
      Overlay.of(context)!.insert(entry);
      return entry.remove;
    }
  }, [isOpen, child]);

  return CompositedTransformTarget(link: layerLink, child: child);
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
