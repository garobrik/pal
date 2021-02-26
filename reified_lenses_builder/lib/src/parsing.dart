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

@meta.immutable
abstract class ElementAnalogue<T extends Element> {
  final T? element;
  final String name;

  const ElementAnalogue({required this.name}) : element = null;

  ElementAnalogue.fromElement(T element)
      : element = element,
        name = element.name ?? '';

  bool hasAnnotation(core.Type t) => element?.hasAnnotation(t) ?? false;

  ConstantReader? getAnnotation(core.Type t) => element?.getAnnotation(t);

  bool get isPrivate => name.startsWith('_');
}

@meta.immutable
abstract class DefinitionHolder<E extends Element> extends ElementAnalogue<E> {
  final Iterable<TypeParam> params;
  late final Iterable<Field> fields;
  late final Iterable<Method> methods;
  late final Iterable<AccessorPair> accessors;

  DefinitionHolder({
    required String name,
    required this.params,
    required this.fields,
    required this.methods,
    required this.accessors,
  }) : super(name: name);

  DefinitionHolder.fromElement(
    E element,
    List<TypeParameterElement> params,
    List<FieldElement> fields,
    List<MethodElement> methods,
    List<PropertyAccessorElement> accessors,
  )   : params = params.map((tp) => TypeParam.fromElement(tp)),
        super.fromElement(element) {
    this.fields =
        fields.where((f) => !f.isSynthetic).map((f) => Field.fromElement(f));

    this.methods = methods.map((m) => Method.fromElement(m));

    final duplicatedAccessors = accessors.where((a) => !a.isSynthetic).map((a) {
      return a.isGetter
          ? AccessorPair.fromElements(getter: a, setter: a.correspondingSetter)
          : AccessorPair.fromElements(getter: a.correspondingGetter, setter: a);
    });

    this.accessors = SplayTreeSet.of(
      duplicatedAccessors,
      (a1, a2) => a1.name.compareTo(a2.name),
    );
  }
}

@meta.immutable
class Class extends DefinitionHolder<ClassElement> with ConcreteType {
  late final Iterable<Constructor> constructors;
  final bool isAbstract;

  Class(
    String name, {
    Iterable<TypeParam> params = const [],
    this.constructors = const [],
    Iterable<Field> fields = const [],
    Iterable<Method> methods = const [],
    Iterable<AccessorPair> accessors = const [],
    this.isAbstract = false,
    bool isPrivate = false,
  }) : super(
          name: name,
          params: params,
          fields: fields,
          methods: methods,
          accessors: accessors,
        );

  Class.fromElement(ClassElement element)
      : isAbstract = element.isAbstract,
        super.fromElement(
          element,
          element.typeParameters,
          element.fields,
          element.methods,
          element.accessors,
        ) {
    constructors =
        element.constructors.map((c) => Constructor.fromElement(c, this));
  }

  @override
  Iterable<Type> get args => params;

  List<TypeParam> newTypeParams(int count) {
    int suffix = 0;
    var result = <TypeParam>[];
    while (result.length < count) {
      final candidateName = 'T$suffix';
      if (this.params.every((param) => param.name != candidateName)) {
        result.add(TypeParam(candidateName));
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

@meta.immutable
class Constructor extends ElementAnalogue<ConstructorElement> {
  final Class parent;
  final Iterable<Param> params;

  const Constructor({
    String name = '',
    this.params = const [],
    required this.parent,
    bool isPrivate = false,
  }) : super(name: name);

  Constructor.fromElement(ConstructorElement element, this.parent)
      : params = element.parameters.map((p) => Param.fromElement(p)),
        super.fromElement(element);

  bool get isDefault => name.isEmpty;
  String get call => '${parent.name}' + (name.isEmpty ? '' : '.$name');
}

@meta.immutable
class Extension extends DefinitionHolder<ExtensionElement> {
  final Type extendedType;

  Extension(
    String name,
    this.extendedType, {
    Iterable<TypeParam> params = const [],
    Iterable<Field> fields = const [],
    Iterable<Method> methods = const [],
    Iterable<AccessorPair> accessors = const [],
  }) : super(
          name: name,
          params: params,
          fields: fields,
          methods: methods,
          accessors: accessors,
        );

  Extension.fromElement(ExtensionElement element)
      : extendedType = Type.fromDartType(element.extendedType),
        super.fromElement(
          element,
          element.typeParameters,
          element.fields,
          element.methods,
          element.accessors,
        );
}

@meta.immutable
class Param extends ElementAnalogue<ParameterElement> {
  final Type type;
  final bool isInitializingFormal;
  final bool isNamed;
  final bool isRequired;
  final String? defaultValue;

  const Param(
    this.type,
    String name, {
    this.isNamed = false,
    this.isRequired = true,
    this.isInitializingFormal = false,
    this.defaultValue,
  }) : super(name: name);

  Param.fromElement(ParameterElement element)
      : type = Type.fromDartType(element.type),
        isNamed = element.isNamed,
        isRequired =
            !element.isOptional || element.hasAnnotation(meta.Required),
        isInitializingFormal = element.isInitializingFormal,
        defaultValue = element.defaultValueCode,
        super.fromElement(element);

  @override
  String toString() {
    final requiredMeta = (isRequired && isNamed) ? 'required ' : '';
    final param = isInitializingFormal ? '$name' : '$type $name';
    final defaultPart = defaultValue == null ? '' : ' = $defaultValue';
    return '$requiredMeta$param$defaultPart';
  }

  @override
  bool operator ==(Object other) =>
      other is Param &&
      [name, isInitializingFormal, isNamed, isRequired].iterableEqual([
        other.name,
        other.isInitializingFormal,
        other.isNamed,
        other.isRequired
      ]) &&
      type.typeEquals(other.type);

  @override
  int get hashCode =>
      hash(<dynamic>[name, isInitializingFormal, isNamed, isRequired]);
}

extension ParamsExtension on Iterable<Param> {
  Iterable<Param> get positional => where((p) => !p.isNamed);
  Iterable<Param> get named => where((p) => p.isNamed);
  Iterable<Param> get required => where((p) => p.isRequired);
  Iterable<Param> get optional => where((p) => !p.isRequired);
}

@meta.immutable
class Field extends ElementAnalogue<FieldElement> {
  final Type type;
  final bool isStatic;
  final bool isFinal;
  final bool isConst;
  final bool isLate;
  final bool isInitialized;

  const Field(
    String name, {
    this.type = Type.dynamic,
    this.isStatic = false,
    this.isFinal = false,
    this.isConst = false,
    this.isLate = false,
    this.isInitialized = false,
    bool isPrivate = false,
  }) : super(name: name);

  Field.fromElement(FieldElement element)
      : type = Type.fromDartType(element.type),
        isStatic = element.isStatic,
        isFinal = element.isFinal,
        isConst = element.isConst,
        isLate = element.isLate,
        isInitialized = element.hasInitializer,
        super.fromElement(element);
}

@meta.immutable
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
  })  : isOperator = overridable_operators.contains(name),
        super(name: name);

  Method.fromElement(MethodElement element)
      : params = element.parameters.map((p) => Param.fromElement(p)),
        typeParams =
            element.typeParameters.map((tp) => TypeParam.fromElement(tp)),
        returnType = element.optionalReturnType,
        isStatic = element.isStatic,
        isOperator = element.isOperator,
        super.fromElement(element);
}

@meta.immutable
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

@meta.immutable
class Getter extends ElementAnalogue<PropertyAccessorElement> {
  final Type returnType;

  const Getter(String name, this.returnType, {bool isPrivate = false})
      : super(name: name);

  Getter.fromElement(PropertyAccessorElement element)
      : returnType = Type.fromDartType(element.returnType),
        super.fromElement(element);
}

@meta.immutable
class Setter extends ElementAnalogue<PropertyAccessorElement> {
  final Type type;

  const Setter(String name, this.type) : super(name: name);

  Setter.fromElement(PropertyAccessorElement element)
      : type = Type.fromDartType(element.type.parameters.first.type),
        super.fromElement(element);
}

@meta.immutable
class TypeParam extends ElementAnalogue<TypeParameterElement>
    with ConcreteType {
  final Type? extendz;

  TypeParam(String name, {this.extendz}) : super(name: name);

  const TypeParam.constant(String name, {this.extendz}) : super(name: name);

  TypeParam.fromElement(TypeParameterElement element)
      : extendz =
            element.bound == null ? null : Type.fromDartType(element.bound!),
        super.fromElement(element);

  String get nameWithBound => extendz == null ? name : '$name extends $extendz';

  TypeParam withBound(Type type) => TypeParam(name, extendz: type);

  @override
  Iterable<Type> get args => const [];

  @override
  bool get isNullable => false;

  @override
  bool operator ==(Object other) =>
      other is TypeParam &&
      name == other.name &&
      ((extendz == null) == (other.extendz == null)) &&
      (extendz?.typeEquals(other.extendz!) ?? true);
}

@meta.immutable
abstract class Type {
  bool typeEquals(Type b);
  String renderType();
  bool get isNullable;

  const factory Type(String name, {Iterable<Type> args, bool isNullable}) =
      ConcreteType;
  factory Type.fromDartType(analyzer_type.DartType t) =>
      t is analyzer_type.FunctionType
          ? FunctionType.fromDartType(t)
          : ConcreteType.fromDartType(t);

  static const Type dynamic = Type('dynamic');
  static const Type object = Type('Object');
  static const Type type = Type('Type');
}

@meta.immutable
class _NullableWrapper implements Type {
  final Type _wrapped;

  _NullableWrapper(this._wrapped) : assert(!_wrapped.isNullable);

  @override
  bool typeEquals(Type b) {
    if (!b.isNullable) return false;
    if (b is _NullableWrapper) return _wrapped.typeEquals(b._wrapped);
    return _wrapped.typeEquals(b);
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

@meta.immutable
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

  FunctionType.fromParams({
    this.returnType,
    Iterable<Param> params = const [],
    this.isNullable = false,
  })  : requiredArgs = params.required.positional.map((p) => p.type),
        optionalArgs = params.optional.positional.map((p) => p.type),
        namedArgs = {for (final p in params.named) p.name: p.type};

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
        isNullable = type.nullabilitySuffix == NullabilitySuffix.question;

  @override
  bool typeEquals(Type b) {
    if (b is FunctionType) {
      if ((b.returnType == null) != (returnType == null)) return false;
      if (returnType != null) {
        if (!returnType!.typeEquals(b.returnType!)) return false;
      }

      if (b.isNullable != isNullable) return false;

      if (requiredArgs.length != b.requiredArgs.length) {
        return false;
      } else {
        final iter1 = requiredArgs.iterator;
        final iter2 = b.requiredArgs.iterator;
        while (iter1.moveNext() && iter2.moveNext()) {
          if (!iter1.current.typeEquals(iter2.current)) return false;
        }
      }

      if (optionalArgs.length != b.optionalArgs.length) {
        return false;
      } else {
        final iter1 = optionalArgs.iterator;
        final iter2 = b.optionalArgs.iterator;
        while (iter1.moveNext() && iter2.moveNext()) {
          if (!iter1.current.typeEquals(iter2.current)) return false;
        }
      }

      if (namedArgs.length != b.namedArgs.length) {
        return false;
      } else {
        for (final entry in namedArgs.entries) {
          if (!b.namedArgs.containsKey(entry.key) ||
              !entry.value.typeEquals(b.namedArgs[entry.key]!)) return false;
        }
      }

      return true;
    }
    return false;
  }

  @override
  String renderType() {
    final output = StringBuffer();
    output.write(returnType == null ? 'void' : returnType!.renderType());
    output.write(' Function(');

    output.write(requiredArgs.map((a) => a.renderType()).join(', '));
    if (optionalArgs.isNotEmpty) {
      if (requiredArgs.isNotEmpty) {
        output.write(', ');
      }
      output.write('[${optionalArgs.map((a) => a.renderType()).join(", ")}');
      if (output.length > 60) output.write(',');
      output.write(']');
    } else if (namedArgs.isNotEmpty) {
      if (requiredArgs.isNotEmpty) {
        output.write(', ');
      }
      output.write(
        '{${namedArgs.entries.map((e) => "${e.value.renderType()} ${e.key}").join(", ")}',
      );
      if (output.length > 60) output.write(',');
      output.write('}');
    } else {
      if (output.length > 60) output.write(',');
    }

    output.write(')');

    if (this.isNullable) {
      output.write('?');
    }

    return output.toString();
  }

  @override
  String toString() => renderType();
}

@meta.immutable
abstract class ConcreteType implements Type {
  String get name;
  Iterable<Type> get args;

  const factory ConcreteType(String name,
      {Iterable<Type> args, bool isNullable}) = _ConcreteTypeImpl;
  factory ConcreteType.fromDartType(analyzer_type.DartType type) =
      _ConcreteTypeImpl.fromDartType;

  @override
  bool typeEquals(Type b) {
    if (b is ConcreteType) {
      if (this.name != b.name || this.args.length != b.args.length) {
        return false;
      }
      if (isNullable != b.isNullable) return false;

      final thisIter = this.args.iterator;
      final bIter = b.args.iterator;
      while (thisIter.moveNext() && bIter.moveNext()) {
        if (!thisIter.current.typeEquals(bIter.current)) return false;
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

@meta.immutable
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
      : name = type.element!.name!,
        args = (type is analyzer_type.ParameterizedType)
            ? type.typeArguments.map((a) => Type.fromDartType(a))
            : [],
        isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
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
    final iterFrom = from.iterator;
    final iterTo = to.iterator;
    while (iterFrom.moveNext() && iterTo.moveNext()) {
      if (this.typeEquals(iterFrom.current)) {
        return iterTo.current;
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

extension IterableEquality<V> on Iterable<V> {
  bool iterableEqual(Iterable<V> other) =>
      length == other.length &&
      zip(this, other).any((pair) => pair.first == pair.second);
}

int hash(Iterable iterable) {
  int result = 1;
  for (final value in iterable) {
    result = 31 * result + value.hashCode;
  }
  return result;
}

class Pair<A, B> {
  final A first;
  final B second;

  Pair(this.first, this.second);
}

Iterable<Pair<A, B>> zip<A, B>(
  Iterable<A> aIterable,
  Iterable<B> bIterable,
) sync* {
  final aIterator = aIterable.iterator;
  final bIterator = bIterable.iterator;
  while (aIterator.moveNext() && bIterator.moveNext()) {
    yield Pair(aIterator.current, bIterator.current);
  }
}
