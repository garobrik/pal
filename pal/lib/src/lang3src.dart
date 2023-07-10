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
  Binding.typed('List', 'FnType(_)(Type)(Type)', '''
    FnDef(E)(Type)(
      FnType(R)(Type)(
        FnType(nil)(R)(
          FnType(cons)(FnType(_)(E)(FnType(_)(R)(R)))(
            R
          )
        )
      )
    )
  '''),
  Binding.typed('empty', 'FnType(E)(Type)(List(E))', '''
    FnDef(E)(Type)(
      FnDef(R)(Type)(
        FnDef(nil)(R)(
          FnDef(_)(FnType(_)(E)(FnType(_)(R)(R)))(
            nil
          )
        )
      )
    )
  '''),
  Binding.typed('append', 'FnType(E)(Type)(FnType(e)(E)(FnType(l)(List(E))(List(E))))', '''
    FnDef(E)(Type)(
      FnDef(e)(E)(
        FnDef(l)(List(E))(
          FnDef(R)(Type)(
            FnDef(nil)(R)(
              FnDef(f)(FnType(_)(E)(FnType(_)(R)(R)))(
                f(e)(l(R)(nil)(f))
              )
            )
          )
        )
      )
    )
  ''')
];
