import 'package:flutter/material.dart';

class AlignedWidgetSpan extends WidgetSpan {
  const AlignedWidgetSpan(Widget child)
      : super(
          child: child,
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
        );
}

class InlineTextSpan extends AlignedWidgetSpan {
  InlineTextSpan({
    required String text,
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
  }) : super(InlineTextField(
          text: text,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
        ));
}

class InlineTextField extends StatelessWidget {
  final String text;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;

  const InlineTextField({super.key, required this.text, this.onChanged, this.onFieldSubmitted});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Builder(
        builder: (context) => Theme(
          data:
              ThemeData(inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none)),
          child: TextFormField(
            initialValue: text,
            decoration: const InputDecoration.collapsed(hintText: null),
            style: Theme.of(context).textTheme.bodyMedium,
            onChanged: onChanged,
            onFieldSubmitted: onFieldSubmitted,
          ),
        ),
      ),
    );
  }
}
