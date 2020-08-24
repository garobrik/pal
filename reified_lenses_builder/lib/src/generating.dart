import 'parsing.dart';

extension FieldGenerating on Field {
  String declaration([String expression]) {
    String staticPrefix = isStatic ? 'static ' : '';
    String suffix = expression != null ? ' = $expression;' : ';';
    return '$staticPrefix $type $name $suffix';
  }
}

extension GetterGenerating on Getter {
  String declaration([String expression]) {
    String suffix = expression != null ? ' => $expression;' : ';';
    return '$returnType get $name $suffix';
  }
}

extension MethodGenerating on Method {
  String declaration([String expression]) {
    String suffix = expression != null ? ' => $expression;' : '{}';
    String returnType = this.returnType.map((t) => t.toString()).or('void');
    String name = '${this.name}${this.typeParams.asDeclaration}';
    return '$returnType $name(${this.params.asDeclaration}) $suffix';
  }
}

String call(String callee, [Iterable<String> args = const []]) {
  return '$callee(${args.join(', ')})';
}

extension TypeParamsGenerating on Iterable<TypeParam> {
  String get asDeclaration {
    String joined = this.map((tp) => tp.nameWithBound).join(', ');
    return joined.isEmpty ? '' : '<$joined>';
  }

  String get asApplication {
    String joined = this.map((tp) => tp.name).join(', ');
    return joined.isEmpty ? '' : '<$joined>';
  }
}

extension ParamsGenerating on Iterable<Param> {
  String get asDeclaration {
    final unnamedRequired = this.where((p) => !p.isNamed && p.isRequired);
    final unnamedOptional = this.where((p) => !p.isNamed && !p.isRequired);
    final named = this.where((p) => p.isNamed);

    final output = StringBuffer();

    output.write(unnamedRequired.join(', '));
    if (unnamedOptional.isNotEmpty)
      output.write('[${unnamedOptional.join(", ")}]');
    if (named.isNotEmpty) output.write('{${named.join(", ")}}');

    return output.toString();
  }
}
