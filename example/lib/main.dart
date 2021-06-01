import 'dart:convert';

import 'package:example/model/table.dart' as model;
import 'package:example/widgets/table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:flutter_portal/flutter_portal.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Portal(
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.green,
        ),
        home: CursorWidget<model.State>(
          create: () => model.State(tables: Dict(), tableIDs: Vec()),
          onChanged: (old, nu, diff) {
            print(old);
            print(nu);
            print(diff);
            print(nu.toJson());
            print(JsonEncoder.withIndent('  ').convert(old));
            print(JsonEncoder.withIndent('  ').convert(old));
            print(diff);
          },
          builder: (_, reader, state) {
            final selectedTable = useState<model.TableID?>(null);

            return Scaffold(
              appBar: AppBar(
                title: Text('knose'),
              ),
              body: selectedTable.value == null
                  ? SizedBox.shrink()
                  : Center(
                      child: TableWidget(
                        state.tables[selectedTable.value!].nonnull,
                        key: ValueKey(selectedTable.value!),
                      ),
                    ),
              drawer: Drawer(
                child: Builder(
                  builder: (context) => ListView(
                    children: [
                      for (final tableID in state.tableIDs.values(reader))
                        TextButton(
                          onPressed: () => selectedTable.value = tableID.read(reader),
                          child:
                              Text(state.tables[tableID.read(reader)].nonnull.title.read(reader)),
                        ),
                      TextButton(
                        onPressed: () {
                          selectedTable.value = state.addTable();
                          Navigator.pop(context);
                        },
                        child: Text('Add Table'),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
