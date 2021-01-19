import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:reified_lenses/reified_lenses.dart';

extension GetCursorBuildExtension<S> on GetCursor<S> {
  Widget build(Widget Function(BuildContext, S) builder, {Key? key}) {
    return CursorBuilder(builder: builder, cursor: this, key: key);
  }
}

class CursorBuilder<S> extends StatefulWidget {
  final Widget Function(BuildContext, S) builder;
  final GetCursor<S> cursor;

  const CursorBuilder({required this.builder, required this.cursor, Key? key})
      : super(key: key);

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
    final withDisposal = widget.cursor.getAndListen(() => setState(() {}));
    disposeFn = withDisposal.dispose;
    return widget.builder(context, withDisposal.value);
  }

  @override
  void dispose() {
    super.dispose();
    if (disposeFn != null) {
      disposeFn!();
    }
  }
}

extension GetCursorBindExtension<S, T extends GetCursor<S>> on T {
  Widget bind(Widget Function(BuildContext b, T t) builder, {Key? key}) {
    return CursorBinder<S, T>(builder: builder, cursor: this, key: key);
  }
}

class CursorBinder<S, T extends GetCursor<S>> extends StatefulWidget {
  final Widget Function(BuildContext, T) builder;
  final T cursor;

  const CursorBinder({required this.builder, required this.cursor, Key? key})
      : super(key: key);

  @override
  _CursorBindState<S, T> createState() => _CursorBindState<S, T>();
}

class _CursorBindState<S, T extends GetCursor<S>>
    extends State<CursorBinder<S, T>> with CursorCallback {
  TrieMap<Object, void Function()> disposals = const TrieMap.empty();
  @override
  Widget build(BuildContext context) {
    for (final dispose in disposals) {
      dispose();
    }
    disposals = const TrieMap.empty();

    return HookBuilder(
      builder: (context) => widget.builder(
        context,
        widget.cursor.withCallback(this) as T,
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
  void onGet<V>(WithDisposal<GetResult<V>> result) {
    disposals = disposals.add(result.value.path, result.dispose);
  }
}

Cursor<S> useBoundCursor<S>(Cursor<S> cursor) =>
    use(_CursorBindHook<S, Cursor<S>>(cursor));

GetCursor<S> useBoundGetCursor<S>(GetCursor<S> cursor) =>
    use(_CursorBindHook<S, GetCursor<S>>(cursor));

class _CursorBindHook<S, T extends GetCursor<S>> extends Hook<T> {
  final T cursor;

  const _CursorBindHook(this.cursor);

  @override
  _CursorBindHookState<S, T> createState() => _CursorBindHookState<S, T>();
}

class _CursorBindHookState<S, T extends GetCursor<S>>
    extends HookState<T, _CursorBindHook<S, T>> with CursorCallback {
  TrieMap<Object, void Function()> disposals = TrieMap.empty();

  @override
  T build(BuildContext context) {
    for (final dispose in disposals) {
      dispose();
    }
    disposals = TrieMap.empty();

    return hook.cursor.withCallback(this) as T;
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
  void onGet<V>(WithDisposal<GetResult<V>> result) {
    disposals = disposals.add(result.value.path, result.dispose);
  }
}
