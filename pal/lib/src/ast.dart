import 'package:pal/src/serialize.dart';

typedef ID = String;

extension Freshen on Iterable<ID> {
  static ID _freshen(ID id) => id.replaceFirstMapped(
        RegExp('[0-9]*\$'),
        (match) => ((int.tryParse(match[0]!) ?? 0) + 1).toString(),
      );

  ID freshen(ID id) {
    while (contains(id)) {
      id = _freshen(id);
    }
    return id;
  }
}

typedef Program = List<List<Binding>>;

class Binding<T extends Object> {
  final ID id;
  final Expr<T>? type;
  final Expr<T>? value;

  const Binding(this.id, this.type, this.value) : assert(type != null || value != null);
}

sealed class Expr<T extends Object> {
  final T? t;
  const Expr({this.t});

  @override
  String toString() => serializeExprIndent(80, withFullHoleNames: true);

  @override
  bool operator ==(Object other) => other is Expr && this.alphaEquiv(other);

  int _hashCode(List<String?> ctx) => switch (this) {
        Var v => Hash.all([!ctx.contains(v.id) ? v.id.hashCode : ctx.indexOf(v.id).hashCode]),
        App app => Hash.all([app.implicit.hashCode, app.fn._hashCode(ctx), app.arg._hashCode(ctx)]),
        Fn fn => Hash.all([
            fn.implicit.hashCode,
            fn.kind.hashCode,
            fn.argType._hashCode(ctx),
            fn.result._hashCode([fn.argID, ...ctx])
          ]),
      };

  @override
  int get hashCode => _hashCode(const []);
}

class Var<T extends Object> extends Expr<T> {
  final ID id;

  const Var(this.id, {super.t});
}

class App<T extends Object> extends Expr<T> {
  final bool implicit;
  final Expr<T> fn;
  final Expr<T> arg;

  const App(this.implicit, this.fn, this.arg, {super.t});
}

enum FnKind { Def, Typ }

class Fn<T extends Object> extends Expr<T> {
  static const Def = FnKind.Def;
  static const Typ = FnKind.Typ;

  final FnKind kind;
  final bool implicit;
  final ID? argID;
  final Expr<T> argType;
  final Expr<T> result;

  const Fn(this.implicit, this.kind, this.argID, this.argType, this.result, {super.t});
  const Fn.def(this.implicit, this.argID, this.argType, this.result, {super.t}) : kind = FnKind.Def;
  const Fn.typ(this.implicit, this.argID, this.argType, this.result, {super.t}) : kind = FnKind.Typ;
}

extension ExprOps<T extends Object> on Expr<T> {
  Set<ID> get freeVars => switch (this) {
        Var(:var id) => {id},
        Fn(:var argID, :var result, :var argType) =>
          result.freeVars.difference({argID}).union(argType.freeVars),
        App(:var fn, :var arg) => fn.freeVars.union(arg.freeVars),
      };

  bool occurs(Var v) => switch (this) {
        Var(:var id) => v.id == id,
        App(:var fn, :var arg) => fn.occurs(v) || arg.occurs(v),
        Fn(:var argID, :var argType, :var result) =>
          argType.occurs(v) || (v.id != argID && result.occurs(v))
      };

  Expr<T> substExpr(ID from, Expr<T> to) {
    switch (this) {
      case Var(:var id):
        return id == from ? to : this;
      case App(:var implicit, :var fn, :var arg):
        return App(implicit, fn.substExpr(from, to), arg.substExpr(from, to));
      case Fn(:var implicit, :var kind, :var argID, :var argType, :var result):
        if (argID == from) {
          return Fn(implicit, kind, argID, argType.substExpr(from, to), result);
        } else if (argID == null) {
          return Fn(implicit, kind, argID, argType.substExpr(from, to), result.substExpr(from, to));
        }
        var newArgID = to.freeVars.difference({argID}).freshen(argID);

        if (argID != newArgID) result = result.substExpr(argID, Var(newArgID));

        return Fn(
          implicit,
          kind,
          newArgID,
          argType.substExpr(from, to),
          result.substExpr(from, to),
        );
    }
  }

  bool alphaEquiv(Expr b, [List<String?> ctxA = const [], List<String?> ctxB = const []]) =>
      switch ((this, b)) {
        (Var(id: var a), Var(id: var b)) =>
          ctxA.indexOf(a) == ctxB.indexOf(b) && (ctxA.contains(a) || (a == b)),
        (App a, App b) => a.implicit == b.implicit &&
            a.fn.alphaEquiv(b.fn, ctxA, ctxB) &&
            a.arg.alphaEquiv(b.arg, ctxA, ctxB),
        (Fn a, Fn b) => a.implicit == b.implicit &&
            a.kind == b.kind &&
            a.argType.alphaEquiv(b.argType, ctxA, ctxB) &&
            a.result.alphaEquiv(b.result, [a.argID, ...ctxA], [b.argID, ...ctxB]),
        _ => false,
      };
}

const typeID = 'Type';
const Type = Var(typeID);

class Hash {
  static int combine(int hash, int value) {
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  static int all(List<int> hashes) => finish(hashes.fold(0, combine));
}
