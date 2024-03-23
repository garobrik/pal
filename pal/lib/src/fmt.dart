import 'dart:io';

import 'parse.dart';
import 'serialize.dart';

void main(List<String> args) {
  final file = File(args.first);
  file.writeAsStringSync(serializeProgram(parseProgram(tokenize(file.readAsStringSync())).$1));
}
