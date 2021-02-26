import 'operators.dart';
import 'parsing.dart';

extension FieldGenerating on Field {
  String declaration([String? expression]) {
    String staticPrefix = isStatic ? 'static ' : '';
    String suffix = expression != null ? ' = $expression;' : ';';
    return '$staticPrefix $type $name $suffix';
  }
}

extension GetterGenerating on Getter {
  String declare({String? body, bool expression = true}) {
    String suffix = body == null
        ? ';'
        : expression
            ? ' => $body;'
            : ' { $body }';
    return '$returnType get $name $suffix';
  }
}

extension ExtensionGenerating on Extension {
  void declare(StringBuffer output, void Function(StringBuffer) declarations) {
    output.writeln('extension $name${params.asDeclaration} on $extendedType {');
    output.writeln();
    declarations(output);
    output.writeln('}');
  }
}

extension ConstructorGenerating on Constructor {
  String invoke(
    Iterable<String> positional, {
    Map<String, String> named = const {},
    Iterable<Type> typeParams = const [],
  }) =>
      call(
        '${parent.name}.${name}',
        positional,
        named: named,
        typeArgs: typeParams,
      );
}

extension MethodGenerating on Method {
  void declare(StringBuffer output, {String? body, bool expression = true}) {
    output.write(this.returnType?.toString() ?? 'void');
    output.write(' ');
    if (isOperator) output.write('operator');
    output.write(name);
    output.write(typeParams.asDeclaration);
    output.write('(${params.asDeclaration})');
    if (body == null) {
      output.write('{}');
    } else if (expression) {
      output.write(' => $body;');
    } else {
      output.writeln('{');
      output.writeln(body);
      output.writeln('}');
    }
    output.writeln();
  }

  String invoke(
    String target, [
    Iterable<String> positional = const [],
    Map<String, String> named = const {},
  ]) {
    final int requiredPositional = params.where((p) => p.isRequired && !p.isNamed).length;
    if (positional.length < requiredPositional) {
      throw ArgumentError(
        'Called method $name with ${positional.length} args. '
        '$requiredPositional are required.',
      );
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

  String invokeFromParams(String target,
      {String? Function(Param) genArg = _paramName, Iterable<Type> typeArgs = const []}) {
    if (overridable_operators.contains(name)) {
      if (name == '[]') {
        final arg = genArg(params.positional.first);
        assert(arg != null);
        return '$target[$arg]';
      } else if (name == '[]=') {
        final arg1 = genArg(params.positional.first);
        final arg2 = genArg(params.positional.skip(1).first);
        assert(arg1 != null && arg2 != null);
        return '$target[$arg1] = $arg2';
      } else if (name == '~') {
        return '~$target';
      } else if (binary_operators.contains(name)) {
        final arg = genArg(params.positional.first);
        assert(arg != null);
        return '$target $name ($arg)';
      }
    }
    return callString('$target.$name', params.asArgs(genArg), typeArgs: typeArgs);
  }
}

String call(
  String callee,
  Iterable<String> positional, {
  Map<String, String> named = const {},
  Iterable<Type> typeArgs = const [],
}) {
  final argString =
      positional.followedBy(named.entries.map((e) => '${e.key}: ${e.value}')).join(', ');
  return callString(
    callee,
    argString,
    typeArgs: typeArgs,
  );
}

String callString(String callee, String args, {Iterable<Type> typeArgs = const []}) {
  final joinedTypeParams = typeArgs.map((t) => t.renderType()).join(', ');
  final renderedTypeParams = joinedTypeParams.isEmpty ? '' : '<$joinedTypeParams>';
  return '$callee$renderedTypeParams($args)';
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
    final output = StringBuffer();

    output.write(positional.required.join(', '));
    if (positional.optional.isNotEmpty) {
      if (positional.required.isNotEmpty) {
        output.write(', ');
      }
      output.write('[${positional.optional.join(", ")}');
      if (output.length > 60) output.write(',');
      output.write(']');
    } else if (named.isNotEmpty) {
      if (positional.required.isNotEmpty) {
        output.write(', ');
      }
      output.write('{${named.join(", ")}');
      if (output.length > 60) output.write(',');
      output.write('}');
    } else {
      if (output.length > 60) output.write(',');
    }

    return output.toString();
  }

  String asArgs([final String? Function(Param) genArg = _paramName]) {
    final output = StringBuffer();

    final genPositional = positional.expand((p) {
      final result = genArg(p);
      assert(!(result == null && p.isRequired));
      return [if (result != null) result];
    });
    final genNamed = named.expand((p) {
      final result = genArg(p);
      assert(!(result == null && p.isRequired));
      return [if (result != null) '${p.name}: $result'];
    });
    output.write(genPositional.join(', '));
    if (named.isNotEmpty) {
      if (positional.isNotEmpty) {
        output.write(', ');
      }
      output.write(genNamed.join(', '));
    }
    if (output.length > 60) output.write(',');

    return output.toString();
  }
}

String _paramName(Param p) => p.name;

String ifElse(Map<String, String> conditionsBodies, {String? elseBody}) {
  final output = StringBuffer();
  var first = true;
  for (final entry in conditionsBodies.entries) {
    if (!first) {
      output.write(' else');
    }
    output.writeln(' if (${entry.key}) {');
    output.writeln(entry.value);
    output.write('}');
    first = false;
  }
  if (elseBody != null) {
    output.writeln(' else {');
    output.writeln(elseBody);
    output.write('}');
  }
  output.writeln();
  return output.toString();
}

String switchCase(String switched, Map<String, String> casesBodies, {String? defaultBody}) {
  final output = StringBuffer();
  output.writeln('switch ($switched) {');
  for (final entry in casesBodies.entries) {
    output.writeln('case ${entry.key}:');
    output.writeln(entry.value);
  }
  if (defaultBody != null) {
    output.writeln('default:');
    output.writeln(defaultBody);
  }
  output.writeln('}');
  return output.toString();
}
