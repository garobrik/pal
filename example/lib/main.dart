//@dart=2.9
import 'package:example/model/table.dart' as model;
import 'package:example/widgets/table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: Provider(
        child: Scaffold(
          body: Consumer<ListenableState<model.Table>>(
            builder: (_, v, __) => Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(5),
              child: TableWidget(v.cursor),
            ),
          ),
        ),
        create: (_) => ListenableState(model.Table.from(columns: [
          for (int column = 0; column < 3; column++)
            model.StringColumn.from(
              values: List.generate(3, (row) => 'Row $row, Column $column'),
              title: 'Column $column',
            )
        ])),
      ),
    );
  }
}
