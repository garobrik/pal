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
    extends State<CursorBinder<S, T>> {
  final PathMap<Object, void Function()> disposals = PathMap.empty();
  @override
  Widget build(BuildContext context) {
    for (final disposeFn in disposals) {
      disposeFn();
    }
    disposals.clear();

    return widget.builder(
      context,
      widget.cursor.withGetCallback(_CursorBindGetCallback(disposals, ()=>setState((){}))) as T,
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (final dispose in disposals) {
      dispose();
    }
  }
}

T useBoundCusor<S, T extends GetCursor<S>>(T cursor) => use(_CursorBindHook<S, T>(cursor));

class _CursorBindHook<S, T extends GetCursor<S>> extends Hook<T> {
  final T cursor;

  const _CursorBindHook(this.cursor);

  @override
  _CursorBindHookState<S, T> createState() => _CursorBindHookState<S, T>();
}

class _CursorBindHookState<S, T extends GetCursor<S>>
    extends HookState<T, _CursorBindHook<S, T>> {
  final PathMap<Object, void Function()> disposals = PathMap.empty();

  @override
  T build(BuildContext context) {
    for (final disposeFn in disposals) {
      disposeFn();
    }
    disposals.clear();

    return hook.cursor.withGetCallback(_CursorBindGetCallback(disposals, () => setState((){}))) as T;
  }

  @override
  void dispose() {
    super.dispose();
    for (final dispose in disposals) {
      dispose();
    }
  }
}

class _CursorBindGetCallback extends GetCallback {
  final PathMap<Object, void Function()> disposals;
  final void Function() onChangedCallback;

  _CursorBindGetCallback(this.disposals, this.onChangedCallback);

  @override
  void onChanged() => onChangedCallback();

  @override
  void onGet<S>(WithDisposal<GetResult<S>> result) {
    disposals.add(result.value.path, result.dispose);
  }
}
