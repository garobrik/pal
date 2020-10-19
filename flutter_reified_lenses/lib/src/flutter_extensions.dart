import 'package:flutter/widgets.dart';
import 'package:reified_lenses/reified_lenses.dart';

extension GetCursorFlutterExtension<S> on GetCursor<S> {
  Widget build(Widget Function(BuildContext, S) builder, {Key key}) {
    return _RebuildableWidget(builder: builder, cursor: this, key: key);
  }
}

class _RebuildableWidget<S> extends StatefulWidget {
  final Widget Function(BuildContext, S) builder;
  final GetCursor<S> cursor;

  const _RebuildableWidget({this.builder, this.cursor, Key key})
      : super(key: key);

  @override
  _RebuildableState<S> createState() => _RebuildableState();
}

class _RebuildableState<S> extends State<_RebuildableWidget<S>> {
  void Function() disposeFn;

  @override
  Widget build(BuildContext context) {
    if (disposeFn != null) disposeFn();
    final withDisposal = widget.cursor.getAndListen(() => setState(() {}));
    disposeFn = withDisposal.dispose;
    return widget.builder(context, withDisposal.value);
  }

  @override
  void dispose() {
    super.dispose();
    disposeFn();
  }
}
