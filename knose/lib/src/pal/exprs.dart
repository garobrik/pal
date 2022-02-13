import 'package:ctx/ctx.dart';
import 'package:flutter_reified_lenses/flutter_reified_lenses.dart';
import 'package:knose/pal.dart';

abstract class Expr {
  const Expr();

  Type evalType(Ctx ctx);
  Object eval(Ctx ctx);
}

Object doEval(Ctx ctx, Object object) {
  return object is Expr ? object.eval(ctx) : object;
}

class Literal extends Expr {
  final Type type;
  final Object value;

  const Literal(this.type, this.value);

  @override
  Type evalType(Ctx ctx) => type;

  @override
  Object eval(Ctx ctx) {
    final result = doTraverse(value, (obj) => doEval(ctx, obj));
    return type.isConcrete ? result : Value(type, result);
  }

  @override
  String toString() => 'PalValue($value: $type)';
}

class FnExpr extends Expr {
  final FnType type;
  final Expr body;

  FnExpr(this.type, this.body);

  @override
  Object eval(Ctx ctx) => this;

  @override
  Type evalType(Ctx ctx) => type;
}

class FnArg extends Expr {
  const FnArg._();

  @override
  Object eval(Ctx ctx) => ctx.fnArg;

  @override
  Type evalType(Ctx ctx) => ctx.fnArgType;
}

const fnArg = FnArg._();

extension FnArgExtension on Ctx {
  Type get fnArgType => get<_FnArgCtx>()!.type;
  Object get fnArg => get<_FnArgCtx>()!.arg;
  Ctx withFnArg(FnType fnType, Object arg) => withElement(_FnArgCtx(fnType.target as Type, arg));
}

class _FnArgCtx extends CtxElement {
  final Type type;
  final Object arg;

  const _FnArgCtx(this.type, this.arg);
}

class InterfaceAccess extends Expr {
  final Expr target;
  final MemberID member;

  InterfaceAccess({
    required this.member,
    this.target = thisImpl,
  });

  @override
  Type evalType(Ctx ctx) {
    final ifaceType = target.evalType(ctx) as InterfaceType;
    {
      final assignment = ifaceType.assignments[member];
      if (assignment != null) {
        return doEval(ctx, assignment) as Type;
      }
    }
    return doEval(ctx, ctx.db.get(ifaceType.id).whenPresent.read(ctx).members[member]!.type)
        as Type;
  }

  @override
  Object eval(Ctx ctx) {
    final impl = target.eval(ctx) as Impl;
    return impl.implementations[member].unwrap!.eval(ctx.withThisImpl(impl));
  }
}

class ThisImpl extends Expr {
  const ThisImpl._();

  @override
  Type evalType(Ctx ctx) => ctx.thisImpl.implemented;

  @override
  Object eval(Ctx ctx) => ctx.thisImpl;
}

const thisImpl = ThisImpl._();

extension ThisImplExtension on Ctx {
  Impl get thisImpl => get<_ThisImplCtx>()!.thisCtx;
  Ctx withThisImpl(Impl value) => withElement(_ThisImplCtx(value));
}

class _ThisImplCtx extends CtxElement {
  final Impl thisCtx;

  const _ThisImplCtx(this.thisCtx);
}

class UnionAccess extends Expr {
  final Expr target;
  final MemberID member;

  const UnionAccess(this.member, this.target);

  @override
  Type evalType(Ctx ctx) {
    final targetType = target.evalType(ctx) as DataType;
    if (targetType.assignments.containsKey(member)) {
      return targetType.assignments[member]! as Type;
    }
    final targetTree =
        ctx.db.get(targetType.id).whenPresent.read(ctx).tree.followPath(targetType.path);

    final resultNode = (targetTree as UnionNode).elements[member]!;
    if (resultNode is LeafNode) {
      return doEval(ctx, resultNode.type) as Type;
    } else {
      return DataType(
        id: targetType.id,
        path: [...targetType.path, member],
        assignments: targetType.assignments,
      );
    }
  }

  @override
  Object eval(Ctx ctx) {
    final targetValue = target.eval(ctx);
    final targetType = target.evalType(ctx) as DataType;
    final dataDef = ctx.db.get(targetType.id).whenPresent.read(ctx);

    return dataDef.followPath(targetValue, [...targetType.path, member]);
  }
}

class RecordAccess extends Expr {
  final Expr target;
  final MemberID member;

  RecordAccess(this.member, {this.target = thisRecord});

  @override
  Type evalType(Ctx ctx) {
    final targetType = target.evalType(ctx) as DataType;
    if (targetType.assignments.containsKey(member)) {
      return targetType.assignments[member]! as Type;
    }
    final targetTree =
        ctx.db.get(targetType.id).whenPresent.read(ctx).tree.followPath(targetType.path);

    final resultNode = (targetTree as RecordNode).elements[member]!;
    if (resultNode is LeafNode) {
      return doEval(ctx, resultNode.type) as Type;
    } else {
      return DataType(
        id: targetType.id,
        path: [...targetType.path, member],
        assignments: targetType.assignments,
      );
    }
  }

  @override
  Object eval(Ctx ctx) {
    final targetValue = target.eval(ctx);
    final targetType = target.evalType(ctx) as DataType;
    final dataDef = ctx.db.get(targetType.id).whenPresent.read(ctx);

    return dataDef.followPath(targetValue, [...targetType.path, member]);
  }
}

class ThisRecord extends Expr {
  const ThisRecord._();

  @override
  Type evalType(Ctx ctx) => ctx.thisRecordType;

  @override
  Object eval(Ctx ctx) => ctx.thisRecord;
}

const thisRecord = ThisRecord._();

extension ThisRecordExtension on Ctx {
  DataType get thisRecordType => get<_ThisRecordCtx>()!.dataType;
  Object get thisRecord => get<_ThisRecordCtx>()!.record;
  Ctx withThisRecord(DataType type, Object record) => withElement(_ThisRecordCtx(type, record));
}

class _ThisRecordCtx extends CtxElement {
  final DataType dataType;
  final Object record;

  const _ThisRecordCtx(this.dataType, this.record);
}

class RecordExpr extends Expr {
  final DataID id;
  final Object tree;

  RecordExpr(Ctx ctx, this.id, Object tree)
      : this.tree = ctx.db.get(id).whenPresent.read(ctx).instantiate(tree);

  @override
  Object eval(Ctx ctx) {
    return ctx.db.get(id).whenPresent.read(ctx).tree.traverse(
          tree,
          (leaf) => (leaf as Expr).eval(ctx),
        );
  }

  @override
  Type evalType(Ctx ctx) {
    return DataType(id: id);
  }
}
