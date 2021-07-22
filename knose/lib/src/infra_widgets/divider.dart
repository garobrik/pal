import 'package:flutter/material.dart';

class MyDivider extends StatelessWidget {
  final Axis direction;
  final double thickness;
  final double padding;
  final Color color;

  const MyDivider({
    Key? key,
    required this.direction,
    this.thickness = 1,
    this.padding = 0,
    this.color = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: direction == Axis.horizontal ? thickness : null,
      height: direction == Axis.vertical ? thickness : null,
      margin: EdgeInsets.symmetric(
        horizontal: direction == Axis.horizontal ? padding : 0,
        vertical: direction == Axis.vertical ? padding : 0,
      ),
      color: color,
    );
  }
}
