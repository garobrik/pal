import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/reified_lenses_generator.dart';
import 'src/flutter_reified_lenses_generator.dart';

/// Builds generators for `build_runner` to run
Builder reifiedLenses(BuilderOptions options) {
  return SharedPartBuilder([const ReifiedLensesGenerator()], 'reified_lenses');
}

Builder flutterReifiedLenses(BuilderOptions options) {
  return SharedPartBuilder([const FlutterReifiedLensesGenerator()], 'flutter_reified_lenses');
}
