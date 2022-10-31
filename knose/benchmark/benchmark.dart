// ignore_for_file: avoid_print

import 'package:ctx/ctx.dart';
import 'package:flutter/material.dart';
import 'package:knose/src/app_widgets/pal_editor.dart';
import 'package:knose/src/pal2/lang.dart' hide List;
import 'package:knose/src/pal2/print.dart';
import 'package:flutter_test/flutter_test.dart';

late final List<String> benchmarks;

void main(List<String> args) {
  benchmarks = args;
  final ctx = Module.load(coreCtx.withFnMap(Printable.fnMap), Printable.module);

  final basicExpr = FnApp.mk(
    Var.mk(Printable.printFnID),
    Literal.mk(Any.type, Any.mk(Module.type, coreModule)),
  );

  benchmark('print core module', () => eval(ctx, basicExpr), 1);
  benchmark('print core module warmed up', () => eval(ctx, basicExpr), 1);

  maybeRun('cursor test', () async {
    await benchmarkWidgets((WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TestThingy(Ctx.empty))));
      final Stopwatch timer = Stopwatch()..start();
      await tester.tap(find.text('core'));
      for (int i = 0; i < 4; i++) {
        await tester.enterText(find.text('core'), 'core'.padLeft(i + 1));
        await tester.pump();
      }
      timer.stop();
      debugPrint('Time taken: ${timer.elapsedMilliseconds / 4}ms');
    });
  });
}

void benchmark(String name, void Function() benchmark, [int iterations = 10]) {
  maybeRun(name, () {
    print('running benchmark $name:');
    final Stopwatch timer = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      benchmark();
    }
    timer.stop();
    print('  Time taken: ${timer.elapsedMilliseconds / iterations}ms');
  });
}

void maybeRun(String name, void Function() toRun) {
  if (benchmarks.isNotEmpty && !benchmarks.any(name.startsWith)) return;
  toRun();
}
