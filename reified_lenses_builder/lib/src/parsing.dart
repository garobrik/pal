import 'dart:collection';
import 'dart:core' as Core;
import 'dart:core';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart' as AnalyzerType;
import 'optional.dart';
import 'package:meta/meta.dart' as Meta;
import 'package:source_gen/source_gen.dart';

import 'operators.dart';

abstract class ElementAnalogue<T extends Element> {
  final Optional<T> element;
  final String name;
  final bool isPrivate;

  const ElementAnalogue({this.name, this.isPrivate = false})
      : element = const Optional.empty();

  ElementAnalogue.fromElement(T element)
      : element = Optional(element),
        name = element.name ?? '',
        isPrivate = element.isPrivate;

  bool hasAnnotation(Core.Type t) =>
      element.hasValue && element.value.hasAnnotation(t);

  Optional<ConstantReader> getAnnotation(Core.Type t) =>
      element.flatMap((e) => e.getAnnotation(t));
}

class Class extends ElementAnalogue<ClassElement> with ConcreteType {
  final Iterable<TypeParam> typeParams;
  Iterable<Constructor> constructors;
  Iterable<Field> fields;
  Iterable<Method> methods;
  Iterable<AccessorPair> accessors;
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
    var result = List<TypeParam>();
    while (result.length < count) {
      if (!this.typeParams.any((param) => param.name == 'T$suffix')) {
        result.add(TypeParam('T$suffix'));
      }
      suffix++;
    }
    return result;
  }

  Optional<Constructor> get defaultCtor => Optional.nullable(
      constructors.firstWhere((c) => c.isDefault, orElse: () => null));
}

class Constructor extends ElementAnalogue<ConstructorElement> {
  final Class parent;
  final Iterable<Param> params;

  const Constructor({
    String name = '',
    this.params = const [],
    this.parent,
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
  final bool isInit;
  final bool isNamed;
  final bool isRequired;

  const Param(
    this.type,
    String name, {
    this.isNamed = false,
    this.isRequired = true,
    this.isInit = false,
    bool isPrivate = false,
  }) : super(name: name, isPrivate: isPrivate);

  Param.fromElement(ParameterElement element)
      : type = Type.fromDartType(element.type),
        isNamed = element.isNamed,
        isRequired =
            !element.isOptional || element.hasAnnotation(Meta.Required),
        isInit = element.isInitializingFormal,
        super.fromElement(element);

  String toString() {
    final requiredMeta = (isRequired && isNamed) ? '@required ' : '';
    final param = isInit ? '$name' : '$type $name';
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
  final Optional<Type> returnType;
  final bool isOperator;

  Method(
    String name, {
    this.typeParams = const [],
    this.params = const [],
    this.returnType = const Optional.empty(),
    bool isPrivate = false,
  })  : isOperator = overridable_operators.contains(name),
        super(name: name, isPrivate: isPrivate);

  Method.fromElement(MethodElement element)
      : params = element.parameters.map((p) => Param.fromElement(p)),
        typeParams =
            element.typeParameters.map((tp) => TypeParam.fromElement(tp)),
        returnType = element.optionalReturnType,
        isOperator = element.isOperator,
        super.fromElement(element);
}

class AccessorPair {
  final String name;
  final Optional<Getter> getter;
  final Optional<Setter> setter;

  const AccessorPair(this.name,
      {this.getter = const Optional.empty(),
      this.setter = const Optional.empty()});

  AccessorPair.fromElements(
      {PropertyAccessorElement getter, PropertyAccessorElement setter})
      : assert(getter != null || setter != null),
        name = getter?.name ?? setter.name,
        getter = Optional.nullable(getter).map((g) => Getter.fromElement(g)),
        setter = Optional.nullable(setter).map((s) => Setter.fromElement(s));

  bool get isPrivate =>
      getter.map((g) => g.isPrivate).orLazy(() => setter.value.isPrivate);
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
  final Optional<Type> extendz;

  TypeParam(String name, {Type extendz, bool isPrivate = false})
      : extendz = Optional.nullable(extendz),
        super(name: name, isPrivate: isPrivate);

  const TypeParam.constant(String name, {this.extendz}) : super(name: name);

  TypeParam.fromElement(TypeParameterElement element)
      : extendz =
            Optional.nullable(element.bound).map((t) => Type.fromDartType(t)),
        super.fromElement(element);

  String get nameWithBound =>
      extendz.map((type) => '$name extends $type').or(name);

  TypeParam withBound(Type type) => TypeParam(name, extendz: type);
  Iterable<Type> get args => const [];
}

abstract class Type {
  bool equals(Type b);
  String renderType();

  const factory Type(String name, [Iterable<Type> args]) = ConcreteType;
  factory Type.fromDartType(AnalyzerType.DartType t) =>
      t is AnalyzerType.FunctionType
          ? FunctionType.fromDartType(t)
          : ConcreteType.fromDartType(t);

  static const Type dynamic = ConcreteType('dynamic');
}

class FunctionType implements Type {
  final Optional<Type> returnType;
  final Iterable<Type> requiredArgs;
  final Iterable<Type> optionalArgs;
  final Map<String, Type> namedArgs;

  const FunctionType({
    this.returnType = const Optional.empty(),
    this.requiredArgs = const [],
    this.optionalArgs = const [],
    this.namedArgs = const {},
  });

  FunctionType.fromDartType(AnalyzerType.FunctionType type)
      : returnType = Optional.ifLazy(
          type.returnType is! AnalyzerType.VoidType,
          () => Type.fromDartType(type.returnType),
        ),
        requiredArgs =
            type.normalParameterTypes.map((t) => Type.fromDartType(t)),
        optionalArgs =
            type.optionalParameterTypes.map((t) => Type.fromDartType(t)),
        namedArgs = type.namedParameterTypes
            .map((name, type) => MapEntry(name, Type.fromDartType(type)));

  @override
  bool equals(Type b) {
    if (b is FunctionType) {
      if (b.returnType.isNotEmpty != returnType.isNotEmpty) return false;
      if (returnType.isNotEmpty) {
        if (!returnType.value.equals(b.returnType.value)) return false;
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
              !entry.value.equals(b.namedArgs[entry.key])) return false;
        }
      }

      return true;
    }
    return false;
  }

  @override
  String renderType() {
    final ret = returnType.map((r) => r.renderType()).or('void');
    final params = requiredArgs.map((a) => a.renderType()).join(', ');
    return '$ret Function($params)';
  }

  @override
  String toString() => renderType();
}

abstract class ConcreteType implements Type {
  String get name;
  Iterable<Type> get args;

  const factory ConcreteType(String name, [Iterable<Type> args]) =
      _ConcreteTypeImpl;
  factory ConcreteType.fromDartType(AnalyzerType.DartType type) =
      _ConcreteTypeImpl.fromDartType;

  bool equals(Type b) {
    if (b is ConcreteType) {
      if (this.name != b.name || this.args.length != b.args.length)
        return false;
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
    return name + (renderedArgs.isNotEmpty ? '<$renderedArgs>' : '');
  }

  @override
  String toString() => renderType();
}

class _ConcreteTypeImpl with ConcreteType {
  final String name;
  final Iterable<Type> args;

  const _ConcreteTypeImpl(this.name, [this.args = const []]);
  _ConcreteTypeImpl.fromDartType(AnalyzerType.DartType type)
      : name = type.element.name,
        args = (type is AnalyzerType.ParameterizedType)
            ? type.typeArguments.map((a) => Type.fromDartType(a))
            : [];
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
      return ConcreteType(
          thisType.name, thisType.args.map((t) => t.subst(from, to)));
    } else if (thisType is FunctionType) {
      return FunctionType(
        returnType: thisType.returnType.map((t) => t.subst(from, to)),
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
  bool hasAnnotation(Core.Type t) => getAnnotation(t).hasValue;
  Optional<ConstantReader> getAnnotation(Core.Type t) =>
      Optional.nullable(TypeChecker.fromRuntime(t).firstAnnotationOfExact(this))
          .map(($) => ConstantReader($));
}

extension on ExecutableElement {
  Optional<Type> get optionalReturnType =>
      Optional.nullable(this.returnType).map((t) => Type.fromDartType(t));
}
