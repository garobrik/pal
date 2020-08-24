import 'dart:collection';
import 'dart:core' as Core;
import 'dart:core';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'optional.dart';
import 'package:meta/meta.dart' as Meta;
import 'package:source_gen/source_gen.dart';

abstract class ElementAnalogue<T extends Element> {
  final Optional<T> element;
  final String name;

  const ElementAnalogue(this.name) : element = const Optional.empty();

  ElementAnalogue.fromElement(T element)
      : element = Optional(element),
        name = element.name ?? '';

  bool hasAnnotation(Core.Type t) =>
      element.hasValue && element.value.hasAnnotation(t);

  Optional<ConstantReader> getAnnotation(Core.Type t) =>
      element.flatMap((e) => e.getAnnotation(t));
}

class Class extends ElementAnalogue<ClassElement> implements Type {
  final Iterable<TypeParam> typeParams;
  Iterable<Constructor> constructors;
  Iterable<Field> fields;
  Iterable<Method> methods;
  Iterable<AccessorPair> accessors;

  Class(
    String name, {
    this.typeParams = const [],
    this.constructors = const [],
    this.fields = const [],
    this.methods = const [],
    this.accessors = const [],
  }) : super(name);

  Class.fromElement(ClassElement element)
      : typeParams =
            element.typeParameters.map((tp) => TypeParam.fromElement(tp)),
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

  TypeParam newTypeParam(String prefix) {
    int suffix = 0;
    String paramName = '\$$prefix';
    while (this.typeParams.any((param) => param.name == paramName)) {
      suffix++;
      paramName = '\$$prefix$suffix';
    }
    return TypeParam(paramName);
  }

  String toString() => '$name' + (args.isEmpty ? '' : '<${args.join(", ")}>');
}

class Constructor extends ElementAnalogue<ConstructorElement> {
  final Class parent;
  final Iterable<Param> params;

  const Constructor({String name = '', this.params = const [], this.parent})
      : super(name);

  Constructor.fromElement(ConstructorElement element, this.parent)
      : params = element.parameters.map((p) => Param.fromElement(p)),
        super.fromElement(element);

  String get call => '${parent.name}' + (name.isEmpty ? '' : '.${name}');
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
  }) : super(name);

  Param.fromElement(ParameterElement element)
      : type = Type.fromDartType(element.type),
        isNamed = element.isNamed,
        isRequired =
            !element.isOptional || element.hasAnnotation(Meta.Required),
        isInit = element.isInitializingFormal,
        super.fromElement(element);

  String toString() {
    final requiredMeta = (isRequired && isNamed) ? '@required ' : '';
    final param = isInit ? 'this.$name' : '$type $name';
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
  }) : super(name);

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

  const Method(
    String name, {
    this.typeParams = const [],
    this.params = const [],
    this.returnType = const Optional.empty(),
  }) : super(name);

  Method.fromElement(MethodElement element)
      : params = element.parameters.map((p) => Param.fromElement(p)),
        typeParams =
            element.typeParameters.map((tp) => TypeParam.fromElement(tp)),
        returnType = element.optionalReturnType,
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
      : name = getter?.name ?? setter.name,
        getter = Optional.nullable(getter).map((g) => Getter.fromElement(g)),
        setter = Optional.nullable(setter).map((s) => Setter.fromElement(s));
}

class Getter extends ElementAnalogue<PropertyAccessorElement> {
  final Type returnType;

  const Getter(String name, this.returnType) : super(name);

  Getter.fromElement(PropertyAccessorElement element)
      : returnType = Type.fromDartType(element.returnType),
        super.fromElement(element);
}

class Setter extends ElementAnalogue<PropertyAccessorElement> {
  final Optional<Type> returnType;

  const Setter(String name, this.returnType) : super(name);

  Setter.fromElement(PropertyAccessorElement element)
      : returnType = element.optionalReturnType,
        super.fromElement(element);
}

class TypeParam extends ElementAnalogue<TypeParameterElement> implements Type {
  final Optional<Type> extendz;

  TypeParam(String name, {Type extendz})
      : extendz = Optional.nullable(extendz),
        super(name);

  const TypeParam.constant(String name, {this.extendz}) : super(name);

  TypeParam.fromElement(TypeParameterElement element)
      : extendz =
            Optional.nullable(element.bound).map((t) => Type.fromDartType(t)),
        super.fromElement(element);

  String get nameWithBound =>
      extendz.map((type) => '$name extends $type').or(name);

  TypeParam withBound(Type type) => TypeParam(name, extendz: type);
  Iterable<Type> get args => const [];

  String toString() => name;
}

class Type {
  final String name;
  final Iterable<Type> args;

  const Type(this.name, [this.args = const []]);
  Type.fromDartType(DartType type)
      : name = type.element.name,
        args = (type is ParameterizedType)
            ? type.typeArguments.map((a) => Type.fromDartType(a))
            : [];
  Type.from(Core.Type type, [this.args = const []]) : name = type.toString();

  static const dynamic = Type('dynamic');

  String toString() => '$name' + (args.isEmpty ? '' : '<${args.join(", ")}>');
}

extension ElementAnnotationExtension on Element {
  bool hasAnnotation(Core.Type t) => getAnnotation(t).hasValue;
  Optional<ConstantReader> getAnnotation(Core.Type t) =>
      Optional.nullable(TypeChecker.fromRuntime(t).firstAnnotationOfExact(this))
          .map(($) => ConstantReader($));
}

extension on ExecutableElement {
  Optional<Type> get optionalReturnType => Optional.ifTrue(
        this.hasImplicitReturnType,
        Type.fromDartType(this.returnType),
      );
}
