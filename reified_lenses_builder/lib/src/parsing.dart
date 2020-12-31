import 'dart:collection';
import 'dart:core' as core;
import 'dart:core';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart' as analyzer_type;
import 'package:meta/meta.dart' as meta;
import 'package:source_gen/source_gen.dart';

import 'operators.dart';

abstract class ElementAnalogue<T extends Element> {
  final T? element;
  final String name;
  final bool isPrivate;

  const ElementAnalogue({required this.name, this.isPrivate = false})
      : element = null;

  ElementAnalogue.fromElement(T element)
      : element = element,
        name = element.name ?? '',
        isPrivate = element.isPrivate;

  bool hasAnnotation(core.Type t) => element?.hasAnnotation(t) ?? false;

  ConstantReader? getAnnotation(core.Type t) => element?.getAnnotation(t);
}

class Class extends ElementAnalogue<ClassElement> with ConcreteType {
  final Iterable<TypeParam> typeParams;
  late final Iterable<Constructor> constructors;
  late final Iterable<Field> fields;
  late final Iterable<Method> methods;
  late final Iterable<AccessorPair> accessors;
  final bool isAbstract;

  Class(
    String name, {
    this.typeParams = const [],
    this.constructors = const [],
    this.fields = const [],
    this.methods = const [],
    this.accessors = const [],
    this.isAbstract = false,
    bool isPrivate = false,
  }) : super(name: name, isPrivate: isPrivate);

  Class.fromElement(ClassElement element)
      : typeParams =
            element.typeParameters.map((tp) => TypeParam.fromElement(tp)),
        isAbstract = element.isAbstract,
        super.fromElement(element) {
    constructors =
        element.constructors.map((c) => Constructor.fromElement(c, this));

    fields = element.fields
        .where((f) => !f.isSynthetic)
        .map((f) => Field.fromElement(f));

    methods = element.methods.map((m) => Method.fromElement(m));

    final duplicatedAccessors =
        element.accessors.where((a) => !a.isSynthetic).map((a) {
      return a.isGetter
          ? AccessorPair.fromElements(getter: a, setter: a.correspondingSetter)
          : AccessorPair.fromElements(getter: a.correspondingGetter, setter: a);
    });

    accessors = SplayTreeSet.of(
      duplicatedAccessors,
      (a1, a2) => a1.name.compareTo(a2.name),
    );
  }

  @override
  Iterable<Type> get args => typeParams;

  List<TypeParam> newTypeParams(int count) {
    int suffix = 0;
    var result = <TypeParam>[];
    while (result.length < count) {
      if (!this.typeParams.any((param) => param.name == 'T$suffix')) {
        result.add(TypeParam('T$suffix'));
      }
      suffix++;
    }
    return result;
  }

  // ignore: unnecessary_cast, doesn't type check otherwise
  Constructor? get defaultCtor => (constructors as Iterable<Constructor?>)
      .firstWhere((c) => c!.isDefault, orElse: () => null);

  @override
  bool get isNullable => false;
}

class Constructor extends ElementAnalogue<ConstructorElement> {
  final Class parent;
  final Iterable<Param> params;

  const Constructor({
    String name = '',
    this.params = const [],
    required this.parent,
    bool isPrivate = false,
  }) : super(name: name, isPrivate: isPrivate);

  Constructor.fromElement(ConstructorElement element, this.parent)
      : params = element.parameters.map((p) => Param.fromElement(p)),
        super.fromElement(element);

  bool get isDefault => name.isEmpty;
  String get call => '${parent.name}' + (name.isEmpty ? '' : '.$name');
}

class Param extends ElementAnalogue<ParameterElement> {
  final Type type;
  final bool isInitializingFormal;
  final bool isNamed;
  final bool isRequired;

  const Param(
    this.type,
    String name, {
    this.isNamed = false,
    this.isRequired = true,
    this.isInitializingFormal = false,
    bool isPrivate = false,
  }) : super(name: name, isPrivate: isPrivate);

  Param.fromElement(ParameterElement element)
      : type = Type.fromDartType(element.type),
        isNamed = element.isNamed,
        isRequired =
            !element.isOptional || element.hasAnnotation(meta.Required),
        isInitializingFormal = element.isInitializingFormal,
        super.fromElement(element);

  @override
  String toString() {
    final requiredMeta = (isRequired && isNamed) ? 'required ' : '';
    final param = isInitializingFormal ? '$name' : '$type $name';
    return '$requiredMeta$param';
  }
}

class Field extends ElementAnalogue<FieldElement> {
  final Type type;
  final bool isStatic;
  final bool isFinal;
  final bool isConst;

  const Field(
    String name, {
    this.type = Type.dynamic,
    this.isStatic = false,
    this.isFinal = false,
    this.isConst = false,
    bool isPrivate = false,
  }) : super(name: name, isPrivate: isPrivate);

  Field.fromElement(FieldElement element)
      : type = Type.fromDartType(element.type),
        isStatic = element.isStatic,
        isFinal = element.isFinal,
        isConst = element.isConst,
        super.fromElement(element);
}

class Method extends ElementAnalogue<MethodElement> {
  final Iterable<TypeParam> typeParams;
  final Iterable<Param> params;
  final Type? returnType;
  final bool isOperator;
  final bool isStatic;

  Method(
    String name, {
    this.typeParams = const [],
    this.params = const [],
    this.returnType,
    this.isStatic = false,
    bool isPrivate = false,
  })  : isOperator = overridable_operators.contains(name),
        super(name: name, isPrivate: isPrivate);

  Method.fromElement(MethodElement element)
      : params = element.parameters.map((p) => Param.fromElement(p)),
        typeParams =
            element.typeParameters.map((tp) => TypeParam.fromElement(tp)),
        returnType = element.optionalReturnType,
        isStatic = element.isStatic,
        isOperator = element.isOperator,
        super.fromElement(element);
}

class AccessorPair {
  final String name;
  final Getter? getter;
  final Setter? setter;

  const AccessorPair(this.name, {this.getter, this.setter})
      : assert(getter != null || setter != null);

  AccessorPair.fromElements(
      {PropertyAccessorElement? getter, PropertyAccessorElement? setter})
      : assert(getter != null || setter != null),
        name = getter?.name ?? setter!.name,
        getter = getter == null ? null : Getter.fromElement(getter),
        setter = setter == null ? null : Setter.fromElement(setter);

  bool get isPrivate => getter?.isPrivate ?? setter!.isPrivate;
}

class Getter extends ElementAnalogue<PropertyAccessorElement> {
  final Type returnType;

  const Getter(String name, this.returnType, {bool isPrivate = false})
      : super(name: name, isPrivate: isPrivate);

  Getter.fromElement(PropertyAccessorElement element)
      : returnType = Type.fromDartType(element.returnType),
        super.fromElement(element);
}

class Setter extends ElementAnalogue<PropertyAccessorElement> {
  final Type type;

  const Setter(String name, this.type, {bool isPrivate = false})
      : super(name: name, isPrivate: isPrivate);

  Setter.fromElement(PropertyAccessorElement element)
      : type = Type.fromDartType(element.type.parameters.first.type),
        super.fromElement(element);
}

class TypeParam extends ElementAnalogue<TypeParameterElement>
    with ConcreteType {
  final Type? extendz;

  TypeParam(String name, {this.extendz, bool isPrivate = false})
      : super(name: name, isPrivate: isPrivate);

  const TypeParam.constant(String name, {this.extendz}) : super(name: name);

  TypeParam.fromElement(TypeParameterElement element)
      : extendz =
            element.bound == null ? null : Type.fromDartType(element.bound),
        super.fromElement(element);

  String get nameWithBound => extendz == null ? name : '$name extends $extendz';

  TypeParam withBound(Type type) => TypeParam(name, extendz: type);

  @override
  Iterable<Type> get args => const [];

  @override
  bool get isNullable => false;
}

abstract class Type {
  bool equals(Type b);
  String renderType();
  bool get isNullable;

  const factory Type(String name, {Iterable<Type> args, bool isNullable}) =
      ConcreteType;
  factory Type.fromDartType(analyzer_type.DartType t) =>
      t is analyzer_type.FunctionType
          ? FunctionType.fromDartType(t)
          : ConcreteType.fromDartType(t);

  static const Type dynamic = ConcreteType('dynamic');
}

class _NullableWrapper implements Type {
  final Type _wrapped;

  _NullableWrapper(this._wrapped) : assert(!_wrapped.isNullable);

  @override
  bool equals(Type b) {
    if (!b.isNullable) return false;
    return b.equals(_wrapped);
  }

  @override
  bool get isNullable => true;

  @override
  String renderType() {
    return '${_wrapped.renderType()}?';
  }

  @override
  String toString() => renderType();
}

class FunctionType implements Type {
  final Type? returnType;
  final Iterable<Type> requiredArgs;
  final Iterable<Type> optionalArgs;
  final Map<String, Type> namedArgs;
  @override
  final bool isNullable;

  const FunctionType({
    this.returnType,
    this.requiredArgs = const [],
    this.optionalArgs = const [],
    this.namedArgs = const {},
    this.isNullable = false,
  });

  FunctionType.fromDartType(analyzer_type.FunctionType type)
      : returnType = type.returnType is! analyzer_type.VoidType
            ? Type.fromDartType(type.returnType)
            : null,
        requiredArgs =
            type.normalParameterTypes.map((t) => Type.fromDartType(t)),
        optionalArgs =
            type.optionalParameterTypes.map((t) => Type.fromDartType(t)),
        namedArgs = type.namedParameterTypes
            .map((name, type) => MapEntry(name, Type.fromDartType(type))),
        isNullable = type.nullabilitySuffix != NullabilitySuffix.none;

  @override
  bool equals(Type b) {
    if (b is FunctionType) {
      if ((b.returnType == null) != (returnType == null)) return false;
      if (returnType != null) {
        if (!returnType!.equals(b.returnType!)) return false;
      }

      if (requiredArgs.length != b.requiredArgs.length) {
        return false;
      } else {
        final iter1 = requiredArgs.iterator;
        final iter2 = b.requiredArgs.iterator;
        while (iter1.moveNext() && iter2.moveNext()) {
          if (!iter1.current.equals(iter2.current)) return false;
        }
      }

      if (optionalArgs.length != b.optionalArgs.length) {
        return false;
      } else {
        final iter1 = optionalArgs.iterator;
        final iter2 = b.optionalArgs.iterator;
        while (iter1.moveNext() && iter2.moveNext()) {
          if (!iter1.current.equals(iter2.current)) return false;
        }
      }

      if (namedArgs.length != b.namedArgs.length) {
        return false;
      } else {
        for (final entry in namedArgs.entries) {
          if (!b.namedArgs.containsKey(entry.key) ||
              !entry.value.equals(b.namedArgs[entry.key]!)) return false;
        }
      }

      return true;
    }
    return false;
  }

  @override
  String renderType() {
    final ret = returnType == null ? 'void' : returnType!.renderType();
    final params = requiredArgs.map((a) => a.renderType()).join(', ');
    return '$ret Function($params)?';
  }

  @override
  String toString() => renderType();
}

abstract class ConcreteType implements Type {
  String get name;
  Iterable<Type> get args;

  const factory ConcreteType(String name,
      {Iterable<Type> args, bool isNullable}) = _ConcreteTypeImpl;
  factory ConcreteType.fromDartType(analyzer_type.DartType type) =
      _ConcreteTypeImpl.fromDartType;

  @override
  bool equals(Type b) {
    if (b is ConcreteType) {
      if (this.name != b.name || this.args.length != b.args.length) {
        return false;
      }
      final thisIter = this.args.iterator;
      final bIter = b.args.iterator;
      while (thisIter.moveNext() && bIter.moveNext()) {
        if (!thisIter.current.equals(bIter.current)) return false;
      }
      return true;
    }
    return false;
  }

  @override
  String renderType() {
    final renderedArgs = args.map((a) => a.renderType()).join(', ');
    return name +
        (renderedArgs.isNotEmpty ? '<$renderedArgs>' : '') +
        (isNullable ? '?' : '');
  }

  @override
  String toString() => renderType();
}

class _ConcreteTypeImpl with ConcreteType {
  @override
  final String name;
  @override
  final Iterable<Type> args;
  @override
  final bool isNullable;

  const _ConcreteTypeImpl(this.name,
      {this.args = const [], this.isNullable = false});
  _ConcreteTypeImpl.fromDartType(analyzer_type.DartType type)
      : name = type.element.name,
        args = (type is analyzer_type.ParameterizedType)
            ? type.typeArguments.map((a) => Type.fromDartType(a))
            : [],
        isNullable = type.nullabilitySuffix != NullabilitySuffix.none;
}

extension AsNullable on Type {
  Type get asNullable {
    if (isNullable) {
      return this;
    } else {
      return _NullableWrapper(this);
    }
  }
}

extension Subst on Type {
  Type subst(Iterable<Type> from, Iterable<Type> to) {
    final iter1 = from.iterator;
    final iter2 = to.iterator;
    while (iter1.moveNext() && iter2.moveNext()) {
      if (this.equals(iter1.current)) {
        return iter2.current;
      }
    }
    final Type thisType = this;
    if (thisType is ConcreteType) {
      return ConcreteType(thisType.name,
          args: thisType.args.map((t) => t.subst(from, to)));
    } else if (thisType is FunctionType) {
      return FunctionType(
        returnType: thisType.returnType?.subst(from, to),
        requiredArgs: thisType.requiredArgs.map((t) => t.subst(from, to)),
        optionalArgs: thisType.optionalArgs.map((t) => t.subst(from, to)),
        namedArgs:
            thisType.namedArgs.map((k, v) => MapEntry(k, v.subst(from, to))),
      );
    }
    throw 'impossible';
  }
}

extension ElementAnnotationExtension on Element {
  bool hasAnnotation(core.Type t) => getAnnotation(t) != null;
  ConstantReader? getAnnotation(core.Type t) {
    final DartObject? typeChecker =
        TypeChecker.fromRuntime(t).firstAnnotationOfExact(this);
    return typeChecker == null ? null : ConstantReader(typeChecker);
  }
}

extension on ExecutableElement {
  Type? get optionalReturnType => Type.fromDartType(this.returnType);
}
