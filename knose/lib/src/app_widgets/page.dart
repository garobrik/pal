import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;

part 'page.g.dart';

@reader_widget
Widget _mainPageWidget(Cursor<model.Page> page) {
  return Container(
    padding: EdgeInsets.all(20),
    child: BoundTextFormField(
      page.contents,
      autofocus: true,
      maxLines: null,
    ),
  );
}
