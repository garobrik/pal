export 'src/table/core.dart';
export 'src/table/value_data.dart';
export 'src/table/list_data.dart';
export 'src/table/link_data.dart';
export 'src/table/widget.dart';

import 'package:knose/src/table/link_data.dart';

import 'src/table/core.dart';
import 'src/table/value_data.dart';
import 'src/table/list_data.dart';

import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/pal.dart' as pal;

final tableDB = () {
  final db = Cursor(const pal.DB());
  for (final dataDef in _dataTypes) {
    db.update(dataDef.id, dataDef);
  }
  for (final interface in _interfaceTypes) {
    db.update(interface.id, interface);
  }
  for (final impl in _implementations) {
    db.update(impl.id, impl);
  }

  return db.read(Ctx.empty);
}();

final _dataTypes = [valueTableDataDef, listTableDataDef, linkTableDataDef];
final _interfaceTypes = [tableDataDef];
final _implementations = [valueTableDataImpl, listTableDataImpl, linkTableDataImpl];
