import 'package:ctx/ctx.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:reified_lenses/reified_lenses.dart';

class CursorWidget<T> extends StatefulWidget {
  final T Function() create;
  final Widget Function(BuildContext, Ctx, Cursor<T>) builder;
  final void Function(T old, T nu, Diff diff)? onChanged;
  final Ctx ctx;

  const CursorWidget({
    Key? key,
    required this.create,
    required this.builder,
    required this.ctx,
    this.onChanged,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CursorWidgetState<T>();
}

class _CursorWidgetState<T> extends State<CursorWidget<T>> {
  late final Cursor<T> cursor;
  void Function()? disposeFn;

  @override
  void initState() {
    super.initState();

    cursor = Cursor(widget.create());
    if (widget.onChanged != null) {
      disposeFn = cursor.listen(widget.onChanged!);
    }
  }

  @override
  Widget build(BuildContext context) => CursorProvider(
        cursor,
        child: ReaderWidget(
          builder: (context, ctx) => widget.builder(context, ctx, cursor),
          ctx: widget.ctx,
        ),
      );

  @override
  void dispose() {
    super.dispose();
    if (disposeFn != null) disposeFn!();
  }
}

class CursorProvider<T> extends InheritedWidget {
  final Cursor<T> cursor;

  const CursorProvider(this.cursor, {required Widget child, Key? key})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(covariant CursorProvider<T> oldWidget) => cursor != oldWidget.cursor;

  static Cursor<T> of<T>(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<CursorProvider<T>>();
    assert(inherited != null, 'Inherited cursor which was never provided.');
    return inherited!.cursor;
  }
}

abstract class ReaderWidget extends StatefulHookWidget {
  final Ctx ctx;

  const factory ReaderWidget({
    Key? key,
    required Ctx ctx,
    required Widget Function(BuildContext context, Ctx ctx) builder,
  }) = _CallbackReaderWidget;

  const ReaderWidget.generative({required this.ctx, Key? key}) : super(key: key);

  @override
  State<ReaderWidget> createState() => _ReaderWidgetState();

  Widget build(BuildContext context, Ctx ctx);
}

class _CallbackReaderWidget extends ReaderWidget {
  final Widget Function(BuildContext context, Ctx ctx) builder;

  const _CallbackReaderWidget({Key? key, required Ctx ctx, required this.builder})
      : super.generative(key: key, ctx: ctx);

  @override
  Widget build(BuildContext context, Ctx ctx) => builder(context, ctx);
}

class _ReaderWidgetState extends State<ReaderWidget> implements Reader {
  final Map<Object, void Function()> disposals = {};
  final Set<Object> keepKeys = {};

  @override
  Widget build(BuildContext context) {
    final oldKeys = {...disposals.keys};
    keepKeys.clear();
    final child = widget.build(context, widget.ctx.withReader(this));
    for (final removeKey in oldKeys.difference(keepKeys)) {
      disposals.remove(removeKey)!();
    }
    return child;
  }

  @override
  void dispose() {
    super.dispose();
    for (final dispose in disposals.values) {
      dispose();
    }
    disposals.clear();
  }

  @override
  void onChanged() => setState(() {});

  @override
  void handleDispose(Object key, void Function() dispose) {
    disposals[key] = dispose;
  }

  @override
  bool isListening(Object key) {
    keepKeys.add(key);
    return disposals.containsKey(key);
  }
}

Cursor<T> useCursor<T>(T initialValue) => useMemoized(() => Cursor(initialValue));
