import 'package:knose/pal.dart' as pal;
import 'package:knose/table.dart';

final baseDB = [
  pal.coreDB,
  tableDB,
].reduce((value, element) => value.merge(element));
