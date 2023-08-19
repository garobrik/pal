import 'lang3.dart';

class Binding {
  final ID id;
  final String? typeSource;
  final String valueSource;

  const Binding(this.id, this.valueSource) : typeSource = null;
  const Binding.typed(this.id, this.typeSource, this.valueSource);
}

const exprs = [
  [
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
  ''')
  ],
  [
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
  ''')
  ],
  [
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
    Binding.typed('fold', '''
      FnType(E)(Type)(FnType(R)(Type)(FnType(_)(FnType(_)(E)(FnType(_)(R)(R)))(
        FnType(_)(R)(FnType(f)(List(E))(
          R
        ))
      )))
    ''', '''
      FnDef(E)(Type)(
        FnDef(R)(Type)(
          FnDef(f)(FnType(_)(E)(FnType(_)(R)(R)))(
            FnDef(init)(R)(
              FnDef(l)(List(E))(
                l(R)(init)(f)
              )
            )
          )
        )
      )
    ''')
  ],
  [
    Binding.typed('reverse', 'FnType(E)(Type)(FnType(l)(List(E))(List(E)))', '''
      FnDef(E)(Type)(
        FnDef(l)(List(E))(
          fold(E)(List(E))(FnDef(e)(E)(
            FnDef(r)(List(E))(
              append(E)(e)(r)
            )
          ))(empty(E))(l)
        )
      )
    '''),
    Binding('foldr', '''
      FnDef(E)(Type)(
        FnDef(R)(Type)(
          FnDef(f)(FnType(_)(E)(FnType(_)(R)(R)))(
            FnDef(init)(R)(
              FnDef(l)(List(E))(
                fold(E)(R)(f)(init)(reverse(E)(l))
              )
            )
          )
        )
      )
    '''),
    Binding.typed('map', '''
      FnType(E)(Type)(FnType(R)(Type)(FnType(f)(FnType(_)(E)(R))(FnType(l)(List(E))(List(R)))))
    ''', '''
      FnDef(E)(Type)(FnDef(R)(Type)(FnDef(f)(FnType(_)(E)(R))(FnDef(l)(List(E))(
        fold(E)(List(R))(FnDef(e)(E)(FnDef(l2)(List(R))(
          append(R)(f(e))(l2)
        ))
      )(l)(empty(R))))))
    '''),
    // https://codereview.stackexchange.com/questions/145874/scanl-expressed-as-fold
    Binding.typed('scanl', '''
    FnType(E)(Type)(FnType(R)(Type)(
      FnType(_)(FnType(_)(E)(FnType(_)(R)(R)))(FnType(_)(R)(FnType(_)(List(E))(List(R))))
    ))
  ''', '''
    FnDef(E)(Type)(FnDef(R)(Type)(
      FnDef(f)(FnType(_)(E)(FnType(_)(R)(R)))(FnDef(z)(R)(FnDef(l)(List(E))(
        foldr(E)(FnType(_)(R)(List(R)))(
          FnDef(e)(E)(FnDef(cont)(FnType(_)(R)(List(R)))(FnDef(acc)(R)(
            append(R)(f(e)(acc))(cont(f(e)(acc)))
          )))
        )(FnDef(_)(R)(empty(R)))(l)(z)
      )))
    ))
  '''),
    Binding.typed('inits', '''
    FnType(E)(Type)(FnType(_)(List(E))(List(List(E))))
  ''', '''
    FnDef(E)(Type)(FnDef(l)(List(E))(
      map(List(E))(List(E))(reverse(E))(
        scanl(E)(List(E))(append(E))(empty(List(E)))(l)
      )
    ))
  '''),
    Binding.typed('tails', '''
    FnType(E)(Type)(FnType(_)(List(E))(List(List(E))))
  ''', '''
    FnDef(E)(Type)(FnDef(l)(List(E))(
      reverse(List(E))(
        map(List(E))(List(E))(reverse(E))(
          inits(E)(reverse(E)(l))
        )
      )
    ))
  ''')
  ],
  [
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
    Binding.typed('DPair.mk', '''
      FnType(T)(Type)(FnType(f)(FnType(_)(T)(Type))(FnType(t)(T)(FnType(t2)(f(t))(DPair(T)(f)))))
    ''', '''
      FnDef(T)(Type)(
        FnDef(f)(FnType(_)(T)(Type))(
          FnDef(t)(T)(
            FnDef(t2)(f(t))(
              FnDef(R)(Type)(
                FnDef(m)(FnType(t')(T)(FnType(_)(f(t'))(R)))(
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
              FnDef(m)(FnType(t)(T)(FnType(_)(f(t))(R)))(
                d(R)(m)
              )
            )
          )
        )
      )
    ''')
  ],
  [
    Binding.typed('DPair.first', '''
      FnType(T)(Type)(FnType(f)(FnType(_)(T)(Type))(FnType(_)(DPair(T)(f))(T)))
    ''', '''
      FnDef(T)(Type)(
        FnDef(f)(FnType(_)(T)(Type))(
          FnDef(d)(DPair(T)(f))(
            DPair.match(T)(f)(T)(d)(FnDef(t)(T)(FnDef(_)(f(t))(t)))
          )
        )
      )
    ''')
  ],
  [
    Binding.typed('HList', 'FnType(l)(List(Type))(Type)', '''
      FnDef(l)(List(Type))(
        FnType(R)(Type)(
          fold(Type)(Type)(
            FnDef(e)(Type)(FnDef(r)(Type)(FnType(_)(e)(r)))
          )(R)(reverse(Type)(l))
        )
      )
    '''),
  ],
];
