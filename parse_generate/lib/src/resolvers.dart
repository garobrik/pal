import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:parse_generate/parse_generate.dart';
import 'package:source_gen/source_gen.dart';

Future<Type> resolveType(
  BuildStep buildStep,
  LibraryElement usageContext,
  String uri,
  String name,
) async {
  final libraryElement = await buildStep.resolver.libraryFor(
    AssetId.resolve(Uri.parse(uri), from: buildStep.inputId),
  );
  final element = libraryElement.exportNamespace.get(name);
  if (element is! ClassElement) {
    throw UnresolvableTypeException(uri, name);
  }
  return Type.fromDartType(usageContext, element.thisType);
}

extension AssignableTo on Type {
  bool isAssignableTo(Type type) =>
      TypeChecker.fromStatic(type.dartType!).isAssignableFromType(dartType!);

  bool isExactly(DartType type) => TypeChecker.fromStatic(type).isExactlyType(dartType!);
}
