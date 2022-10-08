// ignore_for_file: avoid_print

import 'package:ctx/ctx.dart';
import 'package:knose/src/pal2/lang.dart' hide List;
import 'package:knose/src/pal2/print.dart';

late final List<String> benchmarks;

void main(List<String> args) {
  benchmarks = args;
  late final ctx =
      (Option.unwrap(Module.load(coreCtx.withFnMap(Printable.fnMap), Printable.module)) as Ctx);

  final basicExpr = FnApp.mk(
    Var.mk(Printable.printFnID),
    Literal.mk(Any.type, Any.mk(Module.type, coreModule)),
  );

  benchmark('print core module', () => eval(ctx, basicExpr));
}

void benchmark(String name, void Function() benchmark) {
  if (benchmarks.isNotEmpty && !benchmarks.any(name.startsWith)) return;
  print('running benchmark $name:');
  final startTime = DateTime.now();
  benchmark();
  final endTime = DateTime.now();
  final duration = endTime.difference(startTime);
  print('  elapsted time: $duration\n');
}
