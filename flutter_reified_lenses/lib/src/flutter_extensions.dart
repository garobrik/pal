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

class ReaderWidget extends StatefulWidget {
  final Widget Function(BuildContext, Ctx) builder;
  final Ctx ctx;

  const ReaderWidget({required this.builder, required this.ctx, Key? key}) : super(key: key);

  @override
  _ReaderWidgetState createState() => _ReaderWidgetState();
}

class _ReaderWidgetState extends State<ReaderWidget> implements Reader {
  List<void Function()> disposals = [];

  @override
  Widget build(BuildContext context) {
    for (final dispose in disposals) {
      dispose();
    }
    disposals.clear();

    return HookBuilder(
      builder: (context) => widget.builder(
        context,
        widget.ctx.withReader(this),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (final dispose in disposals) {
      dispose();
    }
  }

  @override
  void onChanged() => setState(() {});

  @override
  void handleDispose(void Function() dispose) {
    disposals.add(dispose);
  }
}

Ctx useCursorReader(Ctx ctx) => use(_CursorReaderHook(ctx));

class _CursorReaderHook extends Hook<Ctx> {
  final Ctx ctx;

  const _CursorReaderHook(this.ctx);

  @override
  _CursorReaderHookState createState() => _CursorReaderHookState();
}

class _CursorReaderHookState extends HookState<Ctx, _CursorReaderHook> implements Reader {
  List<void Function()> disposals = [];

  @override
  Ctx build(BuildContext context) {
    for (final dispose in disposals) {
      dispose();
    }
    disposals.clear();

    return hook.ctx.withReader(this);
  }

  @override
  void dispose() {
    super.dispose();
    for (final dispose in disposals) {
      dispose();
    }
  }

  @override
  void onChanged() => setState(() {});

  @override
  void handleDispose(void Function() dispose) {
    disposals.add(dispose);
  }
}

Cursor<T> useCursor<T>(T initialValue) => useMemoized(() => Cursor(initialValue));
