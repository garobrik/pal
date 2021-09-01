import 'package:flutter/widgets.dart';

class InheritedValue<V> extends InheritedWidget {
  final V value;

  InheritedValue({required this.value, required Widget child, Key? key})
      : super(child: child, key: key);

  static V of<V>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InheritedValue<V>>()!.value;

  @override
  bool updateShouldNotify(covariant InheritedValue oldWidget) => this.value != oldWidget.value;
}
