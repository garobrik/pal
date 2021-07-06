import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:knose/model.dart' as model;

part 'table.g.dart';

@reader_widget
Widget mainTableWidget(Cursor<model.Table> table) {
  return Center(child: Text('Table widget'));
}
