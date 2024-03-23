import 'lang.dart';
import 'parse.dart';

String serializeProgram(Program p, {int lineLength = 100}) {
  String serializeBinding(Binding b) {
    String result = b.id;
    final type = b.type?.toString();
    final value = b.value?.toString();
    if (type != null) {
      result += ': ';
      var lines = type.split('\n');
      if (lines.first.length <= 100 - result.length) {
        result += lines.first;
        lines = lines.tail;
        if (lines.isNotEmpty) {
          result += '\n';
          result += lines.join('\n');
        }
      } else {
        result += '\n';
        result += lines.join('\n').indent;
      }
    }
    if (value != null) {
      result += ' = ';
      var lines = value.split('\n');
      if (lines.first.length <= 100 - result.split('\n').last.length) {
        result += lines.first;
        lines = lines.tail;
        if (lines.isNotEmpty) {
          result += '\n';
          result += lines.join('\n');
        }
      } else {
        result += '\n';
        result += lines.join('\n').indent;
      }
    }
    return result;
  }

  String serializeModule(List<Binding> m) => m.map(serializeBinding).join('\n\n');

// ignore: prefer_interpolation_to_compose_strings
  return p.map(serializeModule).join('\n\n--------------------\n\n') + '\n';
}

extension Serialize on Expr {
  String _serializeApp(bool implicit, List<Expr<Object>> args) {
    switch (this) {
      case App(implicit: var im, :var fn, :var arg) when implicit == im:
        return fn._serializeApp(implicit, [arg, ...args]);
      default:
        return '${this._serialize()}${args.map((arg) => arg._serialize()).join(', ').parenthesize(implicit ? '<' : '(')}';
    }
  }

  String _serializeFn(
    bool implicit,
    FnKind kind,
    List<(ID?, Expr<Object>)> args,
    List<(ID?, Expr<Object>)> explicitArgs,
  ) {
    switch (this) {
      case Fn(implicit: var im, kind: var thisKind, :var argID, :var argType, result: var body)
          when thisKind == kind && !(implicit == false && im == true):
        if (im) {
          return body._serializeFn(im, kind, [...args, (argID, argType)], explicitArgs);
        } else {
          return body._serializeFn(im, kind, args, [...explicitArgs, (argID, argType)]);
        }

      default:
        String combineArgs(List<(ID?, Expr<Object>)> args) => args
            .map((pair) =>
                pair.$1 == null ? pair.$2._serialize() : '${pair.$1}: ${pair.$2._serialize()}')
            .join(', ');
        final argPart = args.isEmpty ? '' : combineArgs(args).parenthesize('<');
        final explicitArgPart =
            explicitArgs.isEmpty ? '' : combineArgs(explicitArgs).parenthesize('(');
        final paren = kind == Fn.Def ? '{' : '[';
        final bodyPart = this is Var
            ? this._serialize().parenthesize(paren)
            : ' ${' ${this._serialize()} '.parenthesize(paren)}';

        return '$argPart$explicitArgPart$bodyPart';
    }
  }

  String _serialize() {
    switch (this) {
      case Var(:var id):
        return id;
      case App(:var implicit):
        return this._serializeApp(implicit, []);
      case Fn(:var implicit, :var kind):
        return this._serializeFn(implicit, kind, [], []);
    }
  }

  String _serializeAppIndent(int colRemaining, bool implicit, List<Expr<Object>> args) {
    switch (this) {
      case App(implicit: var im, :var fn, :var arg) when implicit == im:
        return fn._serializeAppIndent(colRemaining, implicit, [arg, ...args]);
      default:
        final oneLine = _serializeApp(implicit, args);
        if (oneLine.length < colRemaining) {
          return oneLine;
        }
        final lines = args.map((arg) => arg.serializeExprIndent(colRemaining - 3).indent);
        final paren = implicit ? '<' : '(';
        return '''
$this$paren
${lines.join(',\n')}
${MATCHING_PAREN[paren]}''';
    }
  }

  String _serializeFnIndent(
    int colRemaining,
    bool implicit,
    FnKind kind,
    List<(ID?, Expr<Object>)> args,
    List<(ID?, Expr<Object>)> explicitArgs,
  ) {
    switch (this) {
      case Fn(implicit: var im, kind: var thisKind, :var argID, :var argType, result: var body)
          when thisKind == kind && !(implicit == false && im == true):
        if (im) {
          return body._serializeFnIndent(
              colRemaining, im, kind, [...args, (argID, argType)], explicitArgs);
        } else {
          return body._serializeFnIndent(
              colRemaining, im, kind, args, [...explicitArgs, (argID, argType)]);
        }
      default:
        final oneLine = _serializeFn(implicit, kind, args, explicitArgs);
        if (oneLine.length < colRemaining) {
          return oneLine;
        }
        String combineArgs(List<(ID?, Expr<Object>)> args) => args
            .map((pair) =>
                pair.$1 == null ? pair.$2._serialize() : '${pair.$1}: ${pair.$2._serialize()}')
            .join(', ');
        final argPart = args.isEmpty ? '' : combineArgs(args).parenthesize('<');
        final explicitArgPart =
            explicitArgs.isEmpty ? '' : combineArgs(explicitArgs).parenthesize('(');
        final paren = kind == Fn.Def ? '{' : '[';
        return '''$argPart$explicitArgPart $paren
${this.serializeExprIndent(colRemaining - 2).indent}
${MATCHING_PAREN[paren]}''';
    }
  }

  String serializeExprIndent(int colRemaining) {
    switch (this) {
      case Var(:var id):
        return id;
      case App(:var implicit):
        return this._serializeAppIndent(colRemaining, implicit, []);
      case Fn(:var implicit, :var kind):
        return this._serializeFnIndent(colRemaining, implicit, kind, [], []);
    }
  }
}

extension on String {
  String get indent => splitMapJoin('\n', onNonMatch: (s) => '  $s');
  String parenthesize(String paren) => '$paren$this${MATCHING_PAREN[paren]}';
}

extension<T> on List<T> {
  List<T> get tail => sublist(1);
}
