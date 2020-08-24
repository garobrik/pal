import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';

part 'main.g.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Provider(
        child: MyHomePage(title: 'Flutter Demo Home Page'),
        create: (_) => ListenableState(CounterHolder()),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    final cursor = Provider.of<ListenableState<CounterHolder>>(context).cursor;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            cursor.counter.build((counter) => Text(
                  '$counter',
                  style: Theme.of(context).textTheme.headline4,
                )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => cursor.counter.mut((counter) => counter + 1),
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}

@reified_lens
class CounterHolder {
  final int counter;

  CounterHolder({this.counter = 0});
}
