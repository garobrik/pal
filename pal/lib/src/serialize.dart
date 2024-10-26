import 'ast.dart';
import 'parse.dart';

String serializeProgram(Program p, {int lineLength = 80}) {
  String serializeBinding(Binding b) {
    String result = b.id;
    final type = b.type?.serializeExprIndent(lineLength, withFullHoleNames: false);
    final value = b.value?.serializeExprIndent(lineLength, withFullHoleNames: false);
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

bool _withFullHoleNames = false;

extension Serialize on Expr {
  bool get isHole => switch (this) { Var(:var id) when id.startsWith('_') => true, _ => false };

  String _serializeApp(bool implicit, List<Expr> args) {
    switch (this) {
      case App(implicit: var im, :var fn, :var arg) when implicit == im:
        return fn._serializeApp(implicit, [arg, ...args]);
      default:
        return '${this._serializeExpr()}${args.map((arg) => arg._serializeExpr()).join(', ').parenthesize(implicit ? '<' : '(')}';
    }
  }

  String _serializeArg(FnKind kind, (ID?, Expr) arg) => switch ((kind, arg)) {
        (Fn.Typ, (null, var expr)) => expr._serializeExpr(),
        (Fn.Typ, (var id, var expr)) when expr.isHole =>
          '${id == null || id.startsWith('_') ? '_' : id}:',
        (Fn.Typ, (var id, var expr)) => '$id: ${expr._serializeExpr()}',
        (Fn.Def, (var id, var expr)) when expr.isHole =>
          id == null || id.startsWith('_') ? '_' : id,
        (Fn.Def, (null, var expr)) => ':${expr._serializeExpr()}',
        (Fn.Def, (var id, var expr)) =>
          '${id == null || id.startsWith('_') ? '_' : id}: ${expr._serializeExpr()}',
      };

  String _combineArgs(FnKind kind, List<(ID?, Expr)> args) =>
      args.map((arg) => _serializeArg(kind, arg)).join(', ');

  String _serializeFn(
    bool implicit,
    FnKind kind,
    List<(ID?, Expr)> args,
    List<(ID?, Expr)> explicitArgs,
  ) {
    switch (this) {
      case Fn(implicit: var im, kind: var thisKind, :var argID, :var argType, :var result)
          when thisKind == kind && !(implicit == false && im == true):
        if (im) {
          return result._serializeFn(im, kind, [...args, (argID, argType)], explicitArgs);
        } else {
          return result._serializeFn(im, kind, args, [...explicitArgs, (argID, argType)]);
        }

      default:
        final argPart = args.isEmpty ? '' : _combineArgs(kind, args).parenthesize('<');
        final explicitArgPart =
            explicitArgs.isEmpty ? '' : _combineArgs(kind, explicitArgs).parenthesize('(');
        final paren = kind == Fn.Def ? '{' : '[';
        final bodyPart = this is Var
            ? this._serializeExpr().parenthesize(paren)
            : ' ${' ${this._serializeExpr()} '.parenthesize(paren)}';

        return '$argPart$explicitArgPart$bodyPart';
    }
  }

  String _serializeExpr() {
    switch (this) {
      case Var(:var id) when id.startsWith('_') && !_withFullHoleNames:
        return '_';
      case Var(:var id):
        return id;
      case App(:var implicit):
        return this._serializeApp(implicit, []);
      case Fn(:var implicit, :var kind):
        return this._serializeFn(implicit, kind, [], []);
    }
  }

  String _serializeAppIndent(int colRemaining, bool implicit, List<Expr> args) {
    switch (this) {
      case App(implicit: var im, :var fn, :var arg) when implicit == im:
        return fn._serializeAppIndent(colRemaining, implicit, [arg, ...args]);
      default:
        final oneLine = _serializeApp(implicit, args);
        if (oneLine.length < colRemaining) {
          return oneLine;
        }
        final lines = args.map((arg) => arg._serializeExprIndent(colRemaining - 3).indent);
        final paren = implicit ? '<' : '(';
        return '''
${this._serializeExprIndent(colRemaining)}$paren
${lines.join(',\n')}
${MATCHING_PAREN[paren]}''';
    }
  }

  String _serializeFnIndent(
    int colRemaining,
    bool implicit,
    FnKind kind,
    List<(ID?, Expr)> args,
    List<(ID?, Expr)> explicitArgs,
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
        final argPart = args.isEmpty ? '' : _combineArgs(kind, args).parenthesize('<');
        final explicitArgPart =
            explicitArgs.isEmpty ? '' : _combineArgs(kind, explicitArgs).parenthesize('(');
        final paren = kind == Fn.Def ? '{' : '[';
        return '''$argPart$explicitArgPart $paren
${this._serializeExprIndent(colRemaining - 2).indent}
${MATCHING_PAREN[paren]}''';
    }
  }

  String _serializeExprIndent(int colRemaining) {
    switch (this) {
      case Var():
        return _serializeExpr();
      case App(:var implicit):
        return this._serializeAppIndent(colRemaining, implicit, []);
      case Fn(:var implicit, :var kind):
        return this._serializeFnIndent(colRemaining, implicit, kind, [], []);
    }
  }

  String serializeExprIndent(int colRemaining, {bool withFullHoleNames = true}) {
    _withFullHoleNames = withFullHoleNames;
    return _serializeExprIndent(colRemaining);
  }
}

extension StringOps on String {
  String get indent => splitMapJoin('\n', onNonMatch: (s) => '  $s');
  String parenthesize(String paren) => '$paren$this${MATCHING_PAREN[paren]}';
  String wrap(String ctx) => ctx.isEmpty ? this : '$ctx\n\n$this';
}

extension<T> on List<T> {
  List<T> get tail => sublist(1);
}
