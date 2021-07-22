import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:reified_lenses/reified_lenses.dart';

class CursorWidget<T> extends StatefulWidget {
  final T Function() create;
  final Widget Function(BuildContext, Reader, Cursor<T>) builder;
  final void Function(T old, T nu, Diff diff)? onChanged;

  const CursorWidget({
    Key? key,
    required this.create,
    required this.builder,
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
          builder: (context, reader) => widget.builder(context, reader, cursor),
        ),
      );

  @override
  void dispose() {
    super.dispose();
    if (disposeFn != null) disposeFn!();
  }
}

class InheritCursor<T> extends StatelessWidget {
  final Widget Function(BuildContext, Reader, Cursor<T>) builder;

  const InheritCursor({Key? key, required this.builder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<CursorProvider<T>>();
    assert(inherited != null, 'Inherited cursor which was never provided.');
    return ReaderWidget(
      builder: (ctx, reader) => builder(ctx, reader, inherited!.cursor),
    );
  }
}

class CursorProvider<T> extends InheritedWidget {
  final Cursor<T> cursor;

  CursorProvider(this.cursor, {required Widget child, Key? key}) : super(key: key, child: child);

  @override
  bool updateShouldNotify(covariant CursorProvider<T> oldWidget) => cursor != oldWidget.cursor;
}

extension GetCursorBuildExtension<S> on GetCursor<S> {
  Widget build(Widget Function(BuildContext, S) builder, {Key? key}) {
    return CursorBuilder(builder: builder, cursor: this, key: key);
  }
}

class CursorBuilder<S> extends StatefulWidget {
  final Widget Function(BuildContext, S) builder;
  final GetCursor<S> cursor;

  const CursorBuilder({required this.builder, required this.cursor, Key? key}) : super(key: key);

  @override
  _CursorBuildState<S> createState() => _CursorBuildState();
}

class _CursorBuildState<S> extends State<CursorBuilder<S>> {
  void Function()? disposeFn;

  @override
  Widget build(BuildContext context) {
    if (disposeFn != null) {
      disposeFn!();
    }
    return widget.builder(
      context,
      widget.cursor.read(
        Reader(
          onChanged: () => setState(() {}),
          handleDispose: (dispose) => disposeFn = dispose,
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    if (disposeFn != null) {
      disposeFn!();
    }
  }
}

class ReaderWidget extends StatefulWidget {
  final Widget Function(BuildContext, Reader) builder;

  const ReaderWidget({required this.builder, Key? key}) : super(key: key);

  @override
  _ReaderWidgetState createState() => _ReaderWidgetState();
}

class _ReaderWidgetState extends State<ReaderWidget> with Reader {
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
        this,
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

Reader useCursorReader() => use(const _CursorReaderHook());

class _CursorReaderHook extends Hook<Reader> {
  const _CursorReaderHook();

  @override
  _CursorReaderHookState createState() => _CursorReaderHookState();
}

class _CursorReaderHookState extends HookState<Reader, _CursorReaderHook> with Reader {
  List<void Function()> disposals = [];

  @override
  Reader build(BuildContext context) {
    for (final dispose in disposals) {
      dispose();
    }
    disposals.clear();

    return this;
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

Cursor<T> useCursor<T>(T initialValue) => use(_CursorHook(initialValue));

class _CursorHook<T> extends Hook<Cursor<T>> {
  final T initialValue;

  _CursorHook(this.initialValue);

  @override
  _CursorHookState<T> createState() => _CursorHookState();
}

class _CursorHookState<T> extends HookState<Cursor<T>, _CursorHook<T>> {
  late final Cursor<T> cursor = Cursor(hook.initialValue);

  @override
  Cursor<T> build(BuildContext context) => cursor;
}
