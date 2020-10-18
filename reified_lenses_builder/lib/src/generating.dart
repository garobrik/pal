import 'operators.dart';
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
    String operator = this.isOperator ? 'operator ' : '';
    String name = '$operator${this.name}${this.typeParams.asDeclaration}';
    return '$returnType $name(${this.params.asDeclaration}) $suffix';
  }

  String invoke(
    String target, [
    Iterable<String> positional,
    Map<String, String> named = const {},
  ]) {
    final int requiredPositional =
        params.where((p) => p.isRequired && !p.isNamed).length;
    if (positional.length < requiredPositional) {
      throw ArgumentError(
          'Called method $name with ${positional.length} args.' +
              '$requiredPositional are required.');
    }

    if (overridable_operators.contains(name)) {
      if (name == '[]') {
        return '$target[${positional.first}]';
      } else if (name == '[]=') {
        return '$target[${positional.first}] = ${positional.skip(1).first}';
      } else if (name == '~') {
        return '~$target';
      } else if (binary_operators.contains(name)) {
        return '$target $name ${positional.first}';
      }
    }
    return call('$target.$name', positional, named: named);
  }
}

String call(
  String callee,
  Iterable<String> positional, {
  Map<String, String> named = const {},
  Iterable<Type> typeParams = const [],
}) {
  final joinedTypeParams = typeParams.map((t) => t.renderType()).join(", ");
  final renderedTypeParams =
      joinedTypeParams.isEmpty ? '' : '<$joinedTypeParams>';
  return '$callee$renderedTypeParams(${parameterize(positional, named)})';
}

String parameterize(
    [Iterable<String> positional = const [],
    Map<String, String> named = const {}]) {
  return positional
      .followedBy(named.entries.map((e) => '${e.key}: ${e.value}'))
      .join(', ');
}

String lambda(Iterable<String> params, Iterable<String> body) {
  final intro = '(${params.join(", ")})';
  if (body.length == 1) return '$intro => ${body.first}';
  return '$intro { ${body.map((s) => s + "; ")}}';
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
