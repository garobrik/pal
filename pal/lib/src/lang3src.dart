import 'lang3.dart';

class Binding {
  final ID id;
  final String? typeSource;
  final String valueSource;

  const Binding(this.id, this.valueSource) : typeSource = null;
  const Binding.typed(this.id, this.typeSource, this.valueSource);
}

const exprs = [
  Binding('let', '''
    FnDef(T)(Type)(
      FnDef(V)(Type)(
        FnDef(var)(V)(
          FnDef(fn)(FnType(_)(V)(T))(
            fn(var)
          )
        )
      )
    )
  '''),
  Binding.typed('Bool', 'Type', '''
    FnType(R)(Type)(FnType(t)(R)(FnType(f)(R)(R)))
  '''),
  Binding.typed('true', 'Bool', '''
    FnDef(R)(Type)(FnDef(t)(R)(FnDef(f)(R)(t)))
  '''),
  Binding.typed('false', 'Bool', '''
    FnDef(R)(Type)(FnDef(t)(R)(FnDef(f)(R)(f)))
  '''),
  Binding.typed('if', 'FnType(R)(Type)(FnType(_)(Bool)(FnType(_)(R)(FnType(_)(R)(R))))', '''
    FnDef(R)(Type)(FnDef(b)(Bool)(FnDef(t)(R)(FnDef(f)(R)(b(R)(t)(f)))))
  '''),
];
