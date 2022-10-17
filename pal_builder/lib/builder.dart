import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'src/pal_generator.dart';

Builder palBuilder(BuilderOptions options) {
  return SharedPartBuilder([const PalGenerator()], 'pal');
}
