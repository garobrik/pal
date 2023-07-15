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
              FnDef(cons)(FnType(_)(E)(FnType(_)(R)(R)))(
                l(R)(cons(e)(nil))(cons)
              )
            )
          )
        )
      )
    )
  '''),
  Binding('fold', '''
    FnDef(E)(Type)(
      FnDef(R)(Type)(
        FnDef(l)(List(E))(
          FnDef(init)(R)(
            FnDef(f)(FnType(_)(E)(FnType(_)(R)(R)))(
              l(R)(init)(f)
            )
          )
        )
      )
    )
  '''),
  Binding.typed('DPair', 'FnType(T)(Type)(FnType(_)(FnType(_)(T)(Type))(Type))', '''
    FnDef(T)(Type)(
      FnDef(f)(FnType(_)(T)(Type))(
        FnType(R)(Type)(
          FnType(_)(FnType(t)(T)(FnType(_)(f(t))(R)))(
            R
          )
        )
      )
    )
  '''),
  Binding.typed(
      'DPair.mk',
      'FnType(T)(Type)(FnType(f)(FnType(_)(T)(Type))(FnType(t)(T)(FnType(t2)(f(T))(DPair(T)(f)))))',
      '''
    FnDef(T)(Type)(
      FnDef(f)(FnType(_)(T)(Type))(
        FnDef(t)(T)(
          FnDef(t2)(f(T))(
            FnDef(R)(Type)(
              FnDef(m)(FnType(t)(T)(FnType(_)(f(t))(R)))(
                m(t)(t2)
              )
            )
          )
        )
      )
    )
'''),
  Binding('DPair.match', '''
    FnDef(T)(Type)(
      FnDef(f)(FnType(_)(T)(Type))(
        FnDef(R)(Type)(
          FnDef(d)(DPair(T)(f))(
            FnDef(f)(FnType(t)(T)(FnType(_)(f(t))(R)))(
              d(R)(f)
            )
          )
        )
      )
    )
  '''),
  Binding.typed('DPair.first',
      'FnType(T)(Type)(FnType(f)(FnType(_)(T)(Type))(FnType(_)(DPair(T)(f))(T)))', '''
    FnDef(T)(Type)(
      FnDef(f)(FnType(_)(T)(Type))(
        FnDef(d)(DPair(T)(f))(
          d(T)(FnDef(t)(T)(FnDef(_)(f(t))(t)))
        )
      )
    )
  ''')
];
