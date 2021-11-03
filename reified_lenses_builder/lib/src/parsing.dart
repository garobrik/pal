import 'dart:collection';
import 'dart:core' as core;
import 'dart:core';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart' as analyzer_type;
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:build/build.dart';
import 'package:meta/meta.dart' as meta;
import 'package:source_gen/source_gen.dart';

import 'operators.dart';

@meta.immutable
abstract class ElementAnalogue<T extends Element> {
  final T? element;
  final String name;
  final Iterable<String> annotations;

  const ElementAnalogue({required this.name, required this.annotations}) : element = null;

  ElementAnalogue.fromElement(LibraryElement usageContext, T element)
      : element = element,
        annotations = const [],
        name = qualifiedNameIn(element, usageContext) ?? '';

  bool hasAnnotation(core.Type t) => element?.hasAnnotation(t) ?? false;

  ConstantReader? getAnnotation(core.Type t) => element?.getAnnotation(t);

  Type getType(analyzer_type.DartType Function(TypeProvider) getter) =>
      Type.fromDartType(element!.library!, getter(element!.library!.typeProvider));

  Type get objectType => getType((provider) => provider.objectType);
  Type get intType => getType((provider) => provider.intType);
  Type get boolType => getType((provider) => provider.boolType);

  bool get isPrivate => name.startsWith('_');
}

String? qualifiedNameIn(Element element, LibraryElement usageContext) {
  if (element.name == null) return null;
  if (element.library == null) return element.name;
  if (!element.library!.topLevelElements.contains(element)) return element.name;
  if (element.library! == usageContext) return element.name;
  final potentialImports = usageContext.imports.where(
    (import) {
      return import.prefix != null &&
          import.namespace.getPrefixed(import.prefix!.name, element.name!) == element;
    },
  );
  if (potentialImports.isNotEmpty) {
    return '${potentialImports.first.prefix!.name}.${element.name}';
  }
  return element.name;
}

@meta.immutable
abstract class DefinitionHolder<E extends Element> extends ElementAnalogue<E> {
  final Iterable<TypeParam> params;
  final Type? extendedType;
  late final Iterable<Field> fields;
  late final Iterable<Method> methods;
  late final Iterable<AccessorPair> accessors;

  DefinitionHolder({
    required String name,
    required this.params,
    required this.fields,
    required this.methods,
    required this.accessors,
    required this.extendedType,
    required Iterable<String> annotations,
  }) : super(name: name, annotations: annotations);

  DefinitionHolder.fromElement(
    LibraryElement usageContext,
    E element,
    List<TypeParameterElement> params,
    List<FieldElement> fields,
    List<MethodElement> methods,
    List<PropertyAccessorElement> accessors,
    this.extendedType, {
    analyzer_type.InterfaceType? interface,
  })  : params = params.map((tp) => TypeParam.fromElement(usageContext, tp)),
        super.fromElement(usageContext, element) {
    final definedFields =
        fields.where((f) => !f.isSynthetic).map((f) => Field.fromElement(usageContext, f));

    late final Iterable<Field>? superFields;
    if (interface != null) {
      superFields = interface.allSupertypes.expand<Field>((superType) sync* {
        final superDefinedFields = superType.element.fields.where((field) => !field.isSynthetic);
        final asInstance = interface.asInstanceOf(superType.element);
        if (asInstance == null) {
          yield* superDefinedFields.map((f) => Field.fromElement(usageContext, f));
          return;
        }

        for (final field in superDefinedFields) {
          final accessor = asInstance.accessors.firstWhere(
            (accessor) => accessor.isGetter && accessor.name == field.name,
          );
          yield Field.fromElement(usageContext, field, type: accessor.returnType);
        }
      });
    } else {
      superFields = null;
    }

    this.fields = [...definedFields, ...?superFields];

    this.methods = methods.map((m) => Method.fromElement(usageContext, m));

    final duplicatedAccessors = accessors.where((a) => !a.isSynthetic).map((a) {
      return a.isGetter
          ? AccessorPair.fromElements(usageContext, getter: a, setter: a.correspondingSetter)
          : AccessorPair.fromElements(usageContext, getter: a.correspondingGetter, setter: a);
    });

    this.accessors = SplayTreeSet.of(
      duplicatedAccessors,
      (a1, a2) => a1.name.compareTo(a2.name),
    );
  }
}

@meta.immutable
class Class extends DefinitionHolder<ClassElement> {
  late final Iterable<Constructor> constructors;
  final bool isAbstract;
  final Type type;

  Class(
    String name, {
    Iterable<TypeParam> params = const [],
    Iterable<Constructor> Function(Class) constructors = _emptyConstructors,
    Iterable<Field> fields = const [],
    Iterable<Method> methods = const [],
    Iterable<AccessorPair> accessors = const [],
    Iterable<String> annotations = const [],
    Type? extendedType,
    this.isAbstract = false,
  })  : type = _ConcreteTypeImpl(name, args: params.map((p) => p.type), isNullable: false),
        super(
          name: name,
          params: params,
          fields: fields,
          methods: methods,
          accessors: accessors,
          extendedType: extendedType,
          annotations: annotations,
        ) {
    this.constructors = constructors(this);
  }

  static Iterable<Constructor> _emptyConstructors(Class _) => const [];

  Class.fromElement(LibraryElement usageContext, ClassElement element)
      : isAbstract = element.isAbstract,
        type = Type.fromDartType(
            usageContext,
            element.instantiate(
              typeArguments: List.from(
                element.typeParameters.map<analyzer_type.DartType>(
                  (tp) => tp.instantiate(nullabilitySuffix: NullabilitySuffix.none),
                ),
              ),
              nullabilitySuffix: NullabilitySuffix.none,
            )),
        super.fromElement(
          usageContext,
          element,
          element.typeParameters,
          element.fields,
          element.methods,
          element.accessors,
          element.supertype?.asInstanceOf(element) == null
              ? null
              : Type.fromDartType(usageContext, element.thisType),
          interface: element.thisType,
        ) {
    constructors = element.constructors.map((c) => Constructor.fromElement(usageContext, c, this));
  }

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
  Constructor? get defaultCtor => constructors.maybeFirstWhere((c) => c.isDefault);
}

@meta.immutable
class Constructor extends ElementAnalogue<ConstructorElement> {
  final Class parent;
  final Iterable<Param> params;
  final String? initializers;
  final bool isConst;
  final bool isFactory;

  const Constructor({
    String name = '',
    this.params = const [],
    required this.parent,
    this.initializers,
    this.isConst = false,
    this.isFactory = false,
    Iterable<String> annotations = const [],
  }) : super(name: name, annotations: annotations);

  Constructor.fromElement(LibraryElement usageContext, ConstructorElement element, this.parent)
      : params = element.parameters.map((p) => Param.fromElement(usageContext, p)),
        initializers = null,
        isConst = element.isConst,
        isFactory = element.isFactory,
        super.fromElement(usageContext, element);

  bool get isDefault => name.isEmpty;
  String get call => '${parent.name}' + (name.isEmpty ? '' : '.$name');
}

@meta.immutable
class Extension extends DefinitionHolder<ExtensionElement> {
  Extension(
    String name,
    Type extendedType, {
    Iterable<TypeParam> params = const [],
    Iterable<Field> fields = const [],
    Iterable<Method> methods = const [],
    Iterable<AccessorPair> accessors = const [],
    Iterable<String> annotations = const [],
  }) : super(
          name: name,
          params: params,
          fields: fields,
          methods: methods,
          accessors: accessors,
          extendedType: extendedType,
          annotations: annotations,
        );

  Extension.fromElement(LibraryElement usageContext, ExtensionElement element)
      : super.fromElement(
          usageContext,
          element,
          element.typeParameters,
          element.fields,
          element.methods,
          element.accessors,
          Type.fromDartType(usageContext, element.extendedType),
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
    Iterable<String> annotations = const [],
  }) : super(name: name, annotations: annotations);

  Param.fromElement(LibraryElement usageContext, ParameterElement element)
      : type = Type.fromDartType(usageContext, element.type),
        isNamed = element.isNamed,
        isRequired = !element.isOptional || element.hasAnnotation(meta.Required),
        isInitializingFormal = element.isInitializingFormal,
        defaultValue = element.defaultValueCode,
        super.fromElement(usageContext, element);

  @override
  String toString() {
    final annotations = this.annotations.isEmpty ? '' : ' ${this.annotations.join(" ")}';
    final requiredMeta = (isRequired && isNamed) ? 'required ' : '';
    final param = isInitializingFormal ? 'this.$name' : '$type $name';
    final defaultPart = defaultValue == null ? '' : ' = $defaultValue';
    return '$annotations$requiredMeta$param$defaultPart';
  }

  @override
  bool operator ==(Object other) =>
      other is Param &&
      [
        name,
        isInitializingFormal,
        isNamed,
        isRequired
      ].iterableEqual([other.name, other.isInitializingFormal, other.isNamed, other.isRequired]) &&
      type.typeEquals(other.type);

  @override
  int get hashCode => hash(<dynamic>[name, isInitializingFormal, isNamed, isRequired]);

  Param copyWith({bool? isInitializingFormal}) => Param(
        type,
        name,
        isInitializingFormal: isInitializingFormal ?? this.isInitializingFormal,
        isNamed: isNamed,
        isRequired: isRequired,
        defaultValue: defaultValue,
      );
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
  final String? initializer;

  const Field(
    String name, {
    required this.type,
    this.isStatic = false,
    this.isFinal = false,
    this.isConst = false,
    this.isLate = false,
    this.initializer,
    bool isPrivate = false,
    Iterable<String> annotations = const [],
  })  : isInitialized = initializer != null,
        super(name: name, annotations: annotations);

  Field.fromElement(LibraryElement usageContext, FieldElement element,
      {analyzer_type.DartType? type})
      : type = Type.fromDartType(usageContext, type ?? element.type),
        isStatic = element.isStatic,
        isFinal = element.isFinal,
        isConst = element.isConst,
        isLate = element.isLate,
        isInitialized = element.hasInitializer,
        initializer = null,
        super.fromElement(usageContext, element);
}

@meta.immutable
class FunctionDefinition extends ElementAnalogue<FunctionElement> {
  final Iterable<TypeParam> typeParams;
  final Iterable<Param> params;
  final Type? returnType;
  final bool isExpression;
  final String? body;

  FunctionDefinition(
    String name, {
    this.typeParams = const [],
    this.params = const [],
    this.returnType,
    this.isExpression = false,
    this.body,
    Iterable<String> annotations = const [],
  }) : super(name: name, annotations: annotations);

  FunctionDefinition.fromElement(LibraryElement usageContext, FunctionElement element)
      : params = element.parameters.map((p) => Param.fromElement(usageContext, p)),
        typeParams = element.typeParameters.map((tp) => TypeParam.fromElement(usageContext, tp)),
        returnType = Type.fromDartType(usageContext, element.returnType),
        isExpression = false,
        body = null,
        super.fromElement(usageContext, element);
}

@meta.immutable
class Method extends ElementAnalogue<MethodElement> {
  final Iterable<TypeParam> typeParams;
  final Iterable<Param> params;
  final Type? returnType;
  final bool isOperator;
  final bool isStatic;
  final bool isExpression;
  final String? body;

  Method(
    String name, {
    this.typeParams = const [],
    this.params = const [],
    this.returnType,
    this.isStatic = false,
    this.isExpression = false,
    this.body,
    Iterable<String> annotations = const [],
  })  : isOperator = overridable_operators.contains(name),
        super(name: name, annotations: annotations);

  Method.fromElement(LibraryElement usageContext, MethodElement element)
      : params = element.parameters.map((p) => Param.fromElement(usageContext, p)),
        typeParams = element.typeParameters.map((tp) => TypeParam.fromElement(usageContext, tp)),
        returnType = Type.fromDartType(usageContext, element.returnType),
        isStatic = element.isStatic,
        isOperator = element.isOperator,
        isExpression = false,
        body = null,
        super.fromElement(usageContext, element);
}

@meta.immutable
class AccessorPair {
  final String name;
  final Getter? getter;
  final Setter? setter;

  const AccessorPair(this.name, {this.getter, this.setter})
      : assert(getter != null || setter != null);

  AccessorPair.fromElements(LibraryElement usageContext,
      {PropertyAccessorElement? getter, PropertyAccessorElement? setter})
      : assert(getter != null || setter != null),
        name = getter?.name ?? setter!.name,
        getter = getter == null ? null : Getter.fromElement(usageContext, getter),
        setter = setter == null ? null : Setter.fromElement(usageContext, setter);

  bool get isPrivate => getter?.isPrivate ?? setter!.isPrivate;
}

@meta.immutable
class Getter extends ElementAnalogue<PropertyAccessorElement> {
  final Type returnType;
  final String? body;
  final bool isExpression;

  const Getter(
    String name,
    this.returnType, {
    bool isPrivate = false,
    this.body,
    this.isExpression = true,
    Iterable<String> annotations = const [],
  }) : super(name: name, annotations: annotations);

  Getter.fromElement(LibraryElement usageContext, PropertyAccessorElement element)
      : returnType = Type.fromDartType(usageContext, element.returnType),
        body = null,
        isExpression = true,
        super.fromElement(usageContext, element);
}

@meta.immutable
class Setter extends ElementAnalogue<PropertyAccessorElement> {
  final Param param;
  final String? body;
  final bool isExpression;

  const Setter(
    String name,
    this.param, {
    Iterable<String> annotations = const [],
    this.body,
    this.isExpression = false,
  }) : super(name: name, annotations: annotations);

  Setter.fromElement(LibraryElement usageContext, PropertyAccessorElement element)
      : param = Param.fromElement(usageContext, element.type.parameters.first),
        body = null,
        isExpression = false,
        super.fromElement(usageContext, element);
}

@meta.immutable
class TypeParam extends ElementAnalogue<TypeParameterElement> {
  final Type? extendz;
  final Type type;

  TypeParam(
    String name, {
    this.extendz,
    Iterable<String> annotations = const [],
  })  : type = _ConcreteTypeImpl(name, isNullable: false),
        super(name: name, annotations: annotations);

  TypeParam.fromElement(LibraryElement usageContext, TypeParameterElement element)
      : extendz = element.bound == null ? null : Type.fromDartType(usageContext, element.bound!),
        type = Type.fromDartType(
          usageContext,
          element.instantiate(nullabilitySuffix: NullabilitySuffix.none),
        ),
        super.fromElement(usageContext, element);

  String get nameWithBound => extendz == null ? name : '$name extends $extendz';

  TypeParam withBound(Type type) => TypeParam(name, extendz: type);

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
  bool get isTypeParameter;
  analyzer_type.DartType? get dartType;
  Type withNullable(bool isNullable);

  const factory Type(String name, {Iterable<Type> args, bool isNullable}) = ConcreteType;
  factory Type.fromDartType(LibraryElement usageContext, analyzer_type.DartType t) =>
      t is analyzer_type.FunctionType
          ? FunctionType.fromDartType(usageContext, t)
          : ConcreteType.fromDartType(usageContext, t);

  static Future<Type> resolveDartType(
    LibraryElement usageContext,
    String importURI,
    String name,
  ) async {
    log.info(' importURI: $importURI');
    final resolvedLibrary = await usageContext.session.getLibraryByUri(importURI);
    log.info(' resolvedLibrary.name: ${resolvedLibrary.name}');
    log.info(' resolvedLibrary: ${resolvedLibrary.source.uri}');
    final resolvedClass = resolvedLibrary.getType(name);
    if (resolvedClass == null) {
      throw UnresolvableTypeException(importURI, name);
    }
    return Type.fromDartType(usageContext, resolvedClass.thisType);
  }

  static const Type dynamic = Type('dynamic');
  static const Type object = Type('Object');
  static const Type type = Type('Type');
  static const Type string = Type('String');
}

class UnresolvableTypeException implements Exception {
  final String uri;
  final String typeName;

  const UnresolvableTypeException(this.uri, this.typeName);

  @override
  String toString() =>
      'UnresolvableTypeException: Could not resolve type $typeName in package $uri.';
}

@meta.immutable
class FunctionType implements Type {
  final Type? returnType;
  final Iterable<Type> requiredArgs;
  final Iterable<Type> optionalArgs;
  final Map<String, Type> namedArgs;
  @override
  final bool isNullable;
  @override
  final analyzer_type.FunctionType? dartType;

  const FunctionType({
    this.returnType,
    this.requiredArgs = const [],
    this.optionalArgs = const [],
    this.namedArgs = const {},
    this.isNullable = false,
  }) : dartType = null;

  FunctionType.fromParams({
    this.returnType,
    Iterable<Param> params = const [],
    this.isNullable = false,
  })  : requiredArgs = params.required.positional.map((p) => p.type),
        optionalArgs = params.optional.positional.map((p) => p.type),
        namedArgs = {for (final p in params.named) p.name: p.type},
        dartType = null;

  FunctionType.fromDartType(LibraryElement usageContext, analyzer_type.FunctionType type)
      : returnType = type.returnType is! analyzer_type.VoidType
            ? Type.fromDartType(usageContext, type.returnType)
            : null,
        requiredArgs = type.normalParameterTypes.map((t) => Type.fromDartType(usageContext, t)),
        optionalArgs = type.optionalParameterTypes.map((t) => Type.fromDartType(usageContext, t)),
        namedArgs = type.namedParameterTypes
            .map((name, type) => MapEntry(name, Type.fromDartType(usageContext, type))),
        isNullable = type.nullabilitySuffix == NullabilitySuffix.question,
        dartType = type;

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

  @override
  Type withNullable(bool isNullable) {
    if (this.isNullable == isNullable) return this;
    return FunctionType(
      returnType: returnType,
      requiredArgs: requiredArgs,
      optionalArgs: optionalArgs,
      namedArgs: namedArgs,
      isNullable: isNullable,
    );
  }

  @override
  bool get isTypeParameter => false;
}

@meta.immutable
abstract class ConcreteType implements Type {
  String get name;
  Iterable<Type> get args;

  const factory ConcreteType(String name, {Iterable<Type> args, bool isNullable}) =
      _ConcreteTypeImpl;
  factory ConcreteType.fromDartType(LibraryElement usageContext, analyzer_type.DartType type) =
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
    return name + (renderedArgs.isNotEmpty ? '<$renderedArgs>' : '') + (isNullable ? '?' : '');
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
  @override
  final bool isTypeParameter;
  @override
  final analyzer_type.DartType? dartType;

  const _ConcreteTypeImpl(this.name,
      {this.args = const [], this.isNullable = false, this.isTypeParameter = false})
      : dartType = null;
  _ConcreteTypeImpl.fromDartType(LibraryElement usageContext, analyzer_type.DartType type)
      : name = qualifiedNameIn(type.element!, usageContext)!,
        args = (type is analyzer_type.ParameterizedType)
            ? type.typeArguments.map((a) => Type.fromDartType(usageContext, a))
            : [],
        isNullable = type.nullabilitySuffix == NullabilitySuffix.question,
        isTypeParameter = type is analyzer_type.TypeParameterType,
        dartType = type;

  @override
  Type withNullable(bool isNullable) {
    if (isNullable == this.isNullable) return this;
    return _ConcreteTypeImpl(this.name, args: this.args, isNullable: isNullable);
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
      return ConcreteType(thisType.name, args: thisType.args.map((t) => t.subst(from, to)));
    } else if (thisType is FunctionType) {
      return FunctionType(
        returnType: thisType.returnType?.subst(from, to),
        requiredArgs: thisType.requiredArgs.map((t) => t.subst(from, to)),
        optionalArgs: thisType.optionalArgs.map((t) => t.subst(from, to)),
        namedArgs: thisType.namedArgs.map((k, v) => MapEntry(k, v.subst(from, to))),
      );
    }
    throw 'impossible';
  }
}

extension ElementAnnotationExtension on Element {
  bool hasAnnotation(core.Type t) => getAnnotation(t) != null;
  ConstantReader? getAnnotation(core.Type t) {
    final DartObject? typeChecker = TypeChecker.fromRuntime(t).firstAnnotationOfExact(this);
    return typeChecker == null ? null : ConstantReader(typeChecker);
  }
}

extension ElementLoggingExtension on Element {
  String get logString {
    return '${location?.components}:$name';
  }
}

extension IterableEquality<V> on Iterable<V> {
  bool iterableEqual(Iterable<V> other) =>
      length == other.length && zip(this, other).any((pair) => pair.first == pair.second);
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

  const Pair(this.first, this.second);
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

extension MaybeIterableFns<T> on Iterable<T> {
  T? maybeFirstWhere(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
