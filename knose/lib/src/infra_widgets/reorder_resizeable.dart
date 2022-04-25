import 'dart:math' as math;

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/infra_widgets.dart';
part 'reorder_resizeable.g.dart';

@reader
Widget _reorderResizeable({
  required Ctx ctx,
  required Axis direction,
  required ReorderCallback onReorder,
  required List<Cursor<double>> mainAxisSizes,
  required List<Widget> children,
  double dragHandlePadding = 5,
}) {
  final widgetIdentifier = useRef(Object()).value;
  final grabbedPosition = useState<int?>(null);
  final grabbedChild = useState<int?>(null);
  final animations = useCursor(const Dict<int, AnimationController>({}));
  useEffect(
    () => () => animations.read(Ctx.empty).entries.forEach((entry) => entry.value.dispose()),
    [0],
  );

  final tickerProvider = useTickerProvider();

  AnimationController _makeAnimation() => AnimationController(
        vsync: tickerProvider,
        duration: const Duration(milliseconds: 0),
      );

  final wrappedChildren = [
    for (int i = 0; i < children.length; i++)
      ReaderWidget(
        key: _ReorderableChildGlobalKey(children[i].key!, widgetIdentifier),
        ctx: ctx,
        builder: (_, ctx) => Container(
            constraints: BoxConstraints.tightFor(
              width: direction == Axis.horizontal ? mainAxisSizes[i].read(ctx) : null,
              height: direction == Axis.vertical ? mainAxisSizes[i].read(ctx) : null,
            ),
            child: children[i]),
      ),
  ];

  final draggableChildren = [
    for (int i = 0; i < children.length; i++)
      DragTarget<int>(
        onWillAccept: (dragData) {
          if (dragData == null || dragData != grabbedChild.value) {
            return false;
          }

          if (grabbedPosition.value == null) {
            grabbedPosition.value = i;
          } else if (grabbedChild.value! > i) {
            if (grabbedPosition.value! > i) {
              grabbedPosition.value = i;
            } else {
              grabbedPosition.value = i + 1;
            }
          } else {
            if (grabbedPosition.value! < i) {
              grabbedPosition.value = i;
            } else {
              grabbedPosition.value = i - 1;
            }
          }

          animations[i].mut((controller) => Optional(controller.unwrap ?? _makeAnimation()));
          animations[i]
              .whenPresent
              .read(Ctx.empty)
              .reverse(from: animations[grabbedChild.value!].read(Ctx.empty).unwrap!.value);
          animations[grabbedChild.value!].read(Ctx.empty).unwrap!.forward(from: 0);

          return true;
        },
        builder: (_, __, ___) => Draggable(
          hitTestBehavior: HitTestBehavior.translucent,
          onDragStarted: () {
            grabbedChild.value = i;
            grabbedPosition.value = i;
            animations[i].mut((controller) => Optional(controller.unwrap ?? _makeAnimation()));
            animations[i].read(Ctx.empty).unwrap!.value = 1.0;
          },
          onDraggableCanceled: (_, __) {
            if (grabbedPosition.value! != grabbedChild.value!) {
              onReorder(grabbedChild.value!, grabbedPosition.value!);
            }
            grabbedPosition.value = null;
            grabbedChild.value = null;
            animations.read(Ctx.empty).entries.forEach((entry) => entry.value.value = 0);
          },
          onDragCompleted: () {
            if (grabbedPosition.value! != grabbedChild.value!) {
              onReorder(grabbedChild.value!, grabbedPosition.value!);
            }
            grabbedPosition.value = null;
            grabbedChild.value = null;
            animations.read(Ctx.empty).entries.forEach((entry) => entry.value.value = 0);
          },
          onDragEnd: (_) {
            if (grabbedPosition.value! != grabbedChild.value!) {
              onReorder(grabbedChild.value!, grabbedPosition.value!);
            }
            grabbedPosition.value = null;
            grabbedChild.value = null;
            animations.read(Ctx.empty).entries.forEach((entry) => entry.value.value = 0);
          },
          data: i,
          axis: direction,
          affinity: direction,
          childWhenDragging: const SizedBox.shrink(),
          feedback: Material(elevation: 5, child: wrappedChildren[i]),
          feedbackOffset:
              Offset(direction == Axis.horizontal ? 0 : 5, direction == Axis.vertical ? 0 : 5),
          child: wrappedChildren[i],
        ),
      ),
  ];

  Widget _makeTransition(int index) => ReaderWidget(
        ctx: ctx,
        builder: (_, ctx) {
          final animation = animations[index].read(ctx);
          return animation.cases(
            none: () => const SizedBox.shrink(),
            some: (animation) => SizeTransition(
              axis: direction,
              sizeFactor: animation,
              child: Container(width: mainAxisSizes[grabbedChild.value!].read(ctx)),
            ),
          );
        },
      );

  final childrenToPass = <Widget>[];
  for (int i = 0; i < children.length; i++) {
    if (grabbedPosition.value == null) {
      childrenToPass.add(draggableChildren[i]);
    } else if (grabbedPosition.value == i) {
      childrenToPass.add(_makeTransition(grabbedChild.value!));
    } else {
      late final int actualIndex;
      if (grabbedChild.value! < grabbedPosition.value!) {
        if (i >= grabbedChild.value! && i < grabbedPosition.value!) {
          actualIndex = i + 1;
        } else {
          actualIndex = i;
        }
      } else if (grabbedChild.value! > grabbedPosition.value!) {
        if (i <= grabbedChild.value! && i > grabbedPosition.value!) {
          actualIndex = i - 1;
        } else {
          actualIndex = i;
        }
      } else {
        actualIndex = i;
      }

      Widget transition = _makeTransition(actualIndex);
      childrenToPass.addAll(
        i < grabbedPosition.value!
            ? [transition, draggableChildren[actualIndex]]
            : [draggableChildren[actualIndex], transition],
      );
    }
  }

  final dragHandles = <Widget>[];
  double totalSize = 0;
  for (final size in mainAxisSizes) {
    totalSize += size.read(ctx);
    dragHandles.add(
      PositionedDirectional(
        start: direction == Axis.horizontal ? totalSize - dragHandlePadding : 0,
        end: direction == Axis.horizontal ? null : 0,
        top: direction == Axis.vertical ? totalSize - dragHandlePadding : 0,
        bottom: direction == Axis.vertical ? null : 0,
        child: Draggable(
          hitTestBehavior: HitTestBehavior.opaque,
          maxSimultaneousDrags: 1,
          onDragUpdate: (details) {
            final delta = direction == Axis.horizontal ? details.delta.dx : details.delta.dy;
            size.set(math.max(size.read(Ctx.empty) + delta, 50));
          },
          feedback: MyDivider(direction: direction, padding: dragHandlePadding),
          child: MyDivider(direction: direction, padding: dragHandlePadding),
        ),
      ),
    );
  }

  return Stack(
    children: [
      Flex(
        direction: direction,
        mainAxisSize: MainAxisSize.min,
        children: childrenToPass,
      ),
      ...dragHandles,
    ],
  );
}

class ListTween<T> extends Tween<List<T>> {
  final T defaultValue;

  ListTween({
    required List<T> begin,
    required List<T> end,
    required this.defaultValue,
  }) : super(begin: begin, end: end);

  @override
  List<T> lerp(double t) {
    final length = math.max(begin?.length ?? 0, end?.length ?? 0);

    return [
      for (int i = 0; i < length; i++)
        Tween(
          begin: i < (begin?.length ?? 0) ? begin?.elementAt(i) : defaultValue,
          end: i < (end?.length ?? 0) ? end?.elementAt(i) : defaultValue,
        ).lerp(t)
    ];
  }
}

class WidthAndOffset {
  final double width;
  final double offset;

  WidthAndOffset({required this.width, required this.offset});

  WidthAndOffset operator +(WidthAndOffset other) =>
      WidthAndOffset(offset: offset + other.offset, width: width + other.width);
  WidthAndOffset operator -(WidthAndOffset other) =>
      WidthAndOffset(offset: offset - other.offset, width: width - other.width);
  WidthAndOffset operator *(double scale) =>
      WidthAndOffset(offset: offset * scale, width: width * scale);

  @override
  bool operator ==(Object other) =>
      other is WidthAndOffset && width == other.width && offset == other.offset;

  @override
  int get hashCode => hashValues(width, offset);
}

@optionalTypeArgs
class _ReorderableChildGlobalKey extends GlobalObjectKey {
  const _ReorderableChildGlobalKey(this.subKey, this.widgetIdentifier) : super(subKey);

  final Key subKey;
  final Object widgetIdentifier;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _ReorderableChildGlobalKey &&
        other.subKey == subKey &&
        other.widgetIdentifier == widgetIdentifier;
  }

  @override
  int get hashCode => hashValues(subKey, widgetIdentifier);
}
