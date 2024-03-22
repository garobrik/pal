import 'dart:io';

import 'lang3.dart';

void main(List<String> args) {
  final file = File(args.first);
  file.writeAsStringSync(serializeProgram(parseProgram(tokenize(file.readAsStringSync())).$1));
}
