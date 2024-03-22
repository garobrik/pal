import 'lang3.dart';

class Binding {
  final ID id;
  final String? typeSource;
  final String? valueSource;

  const Binding(this.id, this.valueSource) : typeSource = null;
  const Binding.typed(this.id, this.typeSource, this.valueSource);
  const Binding.assumed(this.id, this.typeSource) : valueSource = null;
}

const exprs = [
  [Binding('id', '<T: Type>(t: T) {t}')],
  [
    Binding.typed('Eq', '[T: Type, T1: T, T2: T]{ Type }', '''
      <T: Type, T1: T, T2: T>{ [R: Type, f: [[T1]{T2},[T2]{T1}]{R}]{ R } }
    '''),
    Binding.typed(
      'refl',
      '[T: Type, v: T]{ Eq<T, v, v> }',
      '<T: Type, v: T>{ <R: Type>(f: [[v]{v},[v]{v}]{R}){ f(id<v>, id<v>) } }',
    ),
    Binding.typed(
      'subst',
      '[T: Type, T1: T, T2: T, P: Eq<T, T1, T2>, a: T1]{ T2 }',
      '<T: Type, T1: T, T2: T, P: Eq<T, T1, T2>>{ P<[T1]{T2}>((to: [T1]{T2}, [T2]{T1}){ to }) }',
    ),
    Binding.typed(
      'substr',
      '[T: Type, T1: T, T2: T, P: Eq<T, T1, T2>, a: T2]{ T1 }',
      '<T: Type, T1: T, T2: T, P: Eq<T, T1, T2>>{ P<[T2]{T1}>(([T1]{T2}, from: [T2]{T1}){ from }) }',
    )
  ],
  [Binding('let', '(T: Type, V: Type, var: V, fn: [V]{T}) { fn(var) }')],
  [
    Binding.typed('Bool', 'Type', '[R: Type, t: R, f: R]{R}'),
    Binding.typed('true', 'Bool', '<R: Type>(t: R, f: R){t}'),
    Binding.typed('false', 'Bool', '<R: Type>(t: R, f: R){f}'),
    Binding.typed('if', '[R: Type, Bool, R, R]{R}', '<R: Type>(b: Bool, t: R, f: R){ b<R>(t, f) }')
  ],
  [
    Binding.typed('Nat', 'Type', '[R: Type, zero: R, next: [R]{R}] { R }'),
    Binding.typed('zero', 'Nat', '(R: Type, z: R, [R]{R}) { z }'),
    Binding.typed('next', '[Nat]{Nat}', '(n: Nat){ (R: Type, z: R, f: [R]{R}) { f(n<R>(z, f)) } }'),
  ],
  [
    Binding.assumed('NatInd', '''
      [ P: [Nat]{Type}, P(zero), [n: Nat, P(n)]{P(next(n))} ] { [n: Nat]{P(n)} }
    ''')
  ],
  [
    Binding.typed('List', '[Type]{Type}', '''
      <E: Type>{ [R: Type, empty: R, prepend: [E, R]{R} ]{ R } }
    '''),
    Binding.typed('empty', '[E: Type]{ List<E> }', '''
      <E: Type>{ <R: Type>(emp: R, pre: [E, R]{R}){ emp } }
    '''),
    Binding.typed('prepend', '[E: Type, E, List<E>]{List<E>}', '''
      <E: Type>(elem: E, list: List<E>){ 
        <R: Type>(emp: R, pre: [E, R]{R} ){ list<R>(pre(elem, emp), pre) }
      }
    '''),
    Binding.typed('fold', '[R: Type, E: Type, R, [E, R]{R}, List<E>]{ R }', '''
      <R: Type, E: Type>(init: R, f: [E, R]{R}, l: List<E>){ l<R>(init, f) }
    '''),
    Binding.typed(
      'prop_fold_empty',
      '[R: Type, E: Type, init: R, f: [E, R]{R}]{ Eq<R, fold<R, E>(init, f, empty<E>), init> }',
      '<R: Type, E: Type, init: R, f: [E, R]{R}>{ refl<R, init> } ',
    ),
    Binding.typed(
      'prop_fold_prepend',
      '[R: Type, E: Type, init: R, f: [E, R]{R}, e: E, l: List<E>]{ Eq<R, fold<R, E>(init, f, prepend<E>(e, l)), fold<R, E>(f(e, init), f, l)> }',
      '<R: Type, E: Type, init: R, f: [E, R]{R}, e: E, l: List<E>>{ refl<R, fold<R, E>(f(e, init), f, l)> } ',
    ),
  ],
  [
    Binding.typed('length', '[E: Type, List<E>]{Nat}', '''
      <E: Type>{ fold<Nat, E>(zero, (E){ next }) }
    '''),
    Binding.typed('take', '[E: Type, Nat, List<E>]{List<E>}', '''
      <E: Type>(n: Nat){ fold<List<E>, E>(empty<E>, (E, List<E>){ empty<E> }) }
    '''),
  ],
  [
    Binding.assumed(
      'dfold',
      '''
      [E: Type, P: [List<E>]{Type}, P(empty<E>), [l: List<E>, e: E, P(l)]{ P(prepend<E>(e, l)) }]{
        [l: List<E>]{ P(l) }
      }
    ''',
      // ''', '''
      //   FnDef(E)(Type)(
      //     FnDef(P)(FnType(_)(List(E))(Type))(
      //       FnDef(app)(
      //         FnType(l)(List(E))(
      //           FnType(_)(P(l))(FnType(e)(E)(P(prepend(E)(e)(l))))
      //         )
      //       )(
      //         FnDef(emp)(P(empty(E)))(
      //           FnDef(l)(List(E))(
      //             NatInd(FnDef(n)(Nat)(P(take(n)(E)(l))))(
      //               FnDef(n)(Nat)(FnDef(pl)(P(take(n)(E)(l)))(
      //                 app(take(n)(E)(l))(pl)(at(Succ(n))(E)(l))
      //               ))
      //             )(emp
      //             )(length(l)
      //             )
      //           )
      //         )
      //       )
      //     )
      //   )
      // ''')
    )
    // take(0)(l) = empty
    // take(Succ(n))(E)(l) = prepend(E)(head(l))(take(n)(E)(l))
  ],
  [
    Binding.typed('append', '[E: Type, E, List<E>]{List<E>}', '''
      <E: Type>(elem: E){
        fold<List<E>, E>(prepend<E>(elem, empty<E>), prepend<E>)
      }
    '''),
    Binding.typed(
      'Prop_fold_append',
      '[E: Type, List<E>]{ Type }',
      '<E: Type>(l: List<E>) { [R: Type, init: R, f: [E, R]{R}, e: E]{ Eq<R, fold<R, E>(init, f, append<E>(e, l)), f(e, fold<R, E>(init, f, l))> } }',
    ),
    Binding.typed(
      'prop_fold_append',
      '[R: Type, E: Type, init: R, f: [E, R]{R}, e: E, l: List<E>]{ Eq<R, fold<R, E>(init, f, append<E>(e, l)), f(e, fold<R, E>(init, f, l))> }',
      '''<R: Type, E: Type, init: R, f: [E, R]{R}, e: E, l: List<E>>{ 
           dfold<E>(
            Prop_fold_append<E>, 
            (R: Type, init: R, f: [E, R]{R}, e: E){ refl<R, f(e, r)> }, 
            (l_: List<E>, e1: E, acc: Prop_fold_append<E>(l_)){ 
              
              P(prepend<E>(e1, l_)) 

              (R: Type, init: R, f: [E, R]{R}, e2: E){ 
                Eq<R, fold<R, E>(init, f, append<E>(e2, prepend<E>(e1, l_))), f(e2, fold<R, E>(init, f, prepend<E>(e1, l_)))> 
                = Eq<R, fold<R, E>(init, f, append<E>(e2, prepend<E>(e1, l_))), f(e2, fold<R, E>(f(e1, init), f, l_))> 
                = Eq<R, fold<R, E>(init, f, append<E>(e2, prepend<E>(e1, l_))), fold<R, E>(f(e1, init), f, append<E>(e2, l_))> 

              append<E>(e2, prepend<E>(e1, l))
               = fold<List<E>, E>(prepend<E>(e2, empty<E>), prepend<E>, prepend<E>(e1, l))
               = fold<List<E>, E>(prepend<E>(e2, empty<E>), prepend<E>, prepend<E>(e1, l))
              }
            }
           )(l)(R, init, f, e)

         }''',
    ),
  ],
  [
    Binding.typed('Pair', '[Type, Type]{Type}', '''
      <A: Type, B: Type>{[R: Type, [A, B]{R}]{R}}
    '''),
    Binding.typed('Pair.mk', '[A: Type, B: Type]{[A, B]{Pair<A, B>}}', '''
      <A: Type, B: Type>(a: A, b: B){
        <R: Type>(m: [A, B]{R}){ m(a, b) }
      }
    '''),
    Binding.typed('Pair.match', '[A: Type, B: Type]{ [R: Type, [A, B]{R}, Pair<A, B>]{R} }', '''
      <A: Type, B: Type>{ <R: Type>(m: [A, B]{R}, p: Pair<A, B>){p<R>(m)} }
    ''')
  ],
  [
    Binding.typed('reverse', '[E: Type, List<E>]{ List<E> }', '''
      <E: Type>{
        fold<List<E>, E>(empty<E>, (e: E, r: List<E>){
            prepend<E>(e, r)
        })
      }
    '''),
    Binding.typed('foldr', '[R: Type, E: Type, R, [E, R]{R}, List<E>]{R}', '''
      <R: Type, E: Type>(init: R, f: [E, R]{R}, l: List<E>){
        fold<R, E>(init, f, reverse<E>(l))
      }
    '''),
    Binding.assumed(
      'prop_foldr_pre',
      '[R: Type, E: Type, e: E, l: List<E>, init: R, f: [E, R]{R}]{Eq<f(e, foldr<R, E>(init, f, l)), foldr<R, E>(init, f, prepend<E>(e, l))> }',
      // '<R: Type, E: Type, e: E, l: List<E>, init: R, f: [E, R]{R}>(result: f(e, foldr<R, E>(init, f, l))){ result }',
    ),
    Binding.assumed(
      'prop_foldr_app',
      '[R: Type, E: Type, e: E, l: List<E>, init: R, f: [E, R]{R}]{Eq<foldr<R, E>(f(e, init), f, l), foldr<R, E>(init, f, append<E>(e, l))> }',
      // '<R: Type, E: Type, e: E, l: List<E>, init: R, f: [E, R]{R}>(result: f(e, foldr<R, E>(init, f, l))){ result }',
    ),
    // f(e, fold<E, R>)
    //   Binding.typed('map', '''
    //     FnType(E)(Type)(FnType(R)(Type)(FnType(f)(FnType(_)(E)(R))(FnType(l)(List(E))(List(R)))))
    //   ''', '''
    //     FnDef(E)(Type)(FnDef(R)(Type)(FnDef(f)(FnType(_)(E)(R))(FnDef(l)(List(E))(
    //       fold(E)(List(R))(FnDef(e)(E)(FnDef(l2)(List(R))(
    //         prepend(R)(f(e))(l2)
    //       ))
    //     )(l)(empty(R))))))
    //   '''),
    //   // https://codereview.stackexchange.com/questions/145874/scanl-expressed-as-fold
    //   Binding.typed('scanl', '''
    //   FnType(E)(Type)(FnType(R)(Type)(
    //     FnType(_)(FnType(_)(E)(FnType(_)(R)(R)))(FnType(_)(R)(FnType(_)(List(E))(List(R))))
    //   ))
    // ''', '''
    //   FnDef(E)(Type)(FnDef(R)(Type)(
    //     FnDef(f)(FnType(_)(E)(FnType(_)(R)(R)))(FnDef(z)(R)(FnDef(l)(List(E))(
    //       foldr(E)(FnType(_)(R)(List(R)))(
    //         FnDef(e)(E)(FnDef(cont)(FnType(_)(R)(List(R)))(FnDef(acc)(R)(
    //           prepend(R)(f(e)(acc))(cont(f(e)(acc)))
    //         )))
    //       )(FnDef(_)(R)(empty(R)))(l)(z)
    //     )))
    //   ))
    // '''),
    //   Binding.typed('inits', '''
    //   FnType(E)(Type)(FnType(_)(List(E))(List(List(E))))
    // ''', '''
    //   FnDef(E)(Type)(FnDef(l)(List(E))(
    //     map(List(E))(List(E))(reverse(E))(
    //       scanl(E)(List(E))(prepend(E))(empty(List(E)))(l)
    //     )
    //   ))
    // '''),
    //   Binding.typed('tails', '''
    //   FnType(E)(Type)(FnType(_)(List(E))(List(List(E))))
    // ''', '''
    //   FnDef(E)(Type)(FnDef(l)(List(E))(
    //     reverse(List(E))(
    //       map(List(E))(List(E))(reverse(E))(
    //         inits(E)(reverse(E)(l))
    //       )
    //     )
    //   ))
    // ''')
  ],
  [
    Binding.typed('List2Fn', '[Type, List<Type>]{Type}', '''
      <R: Type> { foldr<Type, Type>(R, (E: Type, Acc: Type){ [E]{Acc} }) }
    '''),
    Binding.assumed('prop_List2Fn_pre',
        '[R: Type, L: List<Type>, E: Type]{ Eq<List2Fn<R, prepend<Type>(E, L)>,  [E]{List2Fn<R, L>}> }'),
    Binding.assumed('prop_List2Fn_app',
        '[R: Type, L: List<Type>, E: Type]{ Eq<List2Fn<[E]{R}, L>, List2Fn<R, append<Type>(E, L)>> }'),
    Binding.typed('HList', '[List<Type>]{Type}', '''
      (l: List<Type>) { [R: Type, List2Fn<R, l>]{ R } }
    '''),
    Binding('HListInd', '''
      (L: List<Type>){
        [W: List<Type>, w: HList<W>]{ 
          List2Fn<
            [R: Type, List2Fn<List2Fn<R, L>, W>]{R}, 
            L
          >
        }
      }
    '''),
    Binding.typed('HList.mk', '''
      [L: List<Type>]{List2Fn<HList<L>, L>}
    ''', '''
      <L: List<Type>>{
        dfold<Type, HListInd>(
          (W: List<Type>, w: HList<W>) { w },
          <Rest: List<Type>, E: Type>(acc: HListInd<Rest>) {
            (W: List<Type>, w: HList<W>) {
              substr(
                List2Fn<
                  [R: Type, List2Fn<List2Fn<R, W>, append<Type>(E, Rest)>]{R}, 
                  prepend<Type>(E, Rest)
                >,
                [E]{
                  List2Fn<
                    [R: Type, List2Fn<List2Fn<R, W>, append<Type>(E, Rest)>]{R}, 
                    Rest
                  >
                }, 
                prop_List2Fn_pre<
                  [R: Type, List2Fn<List2Fn<R, W>, append<Type>(E, Rest)>]{R}, 
                  Rest, 
                  E
                >, 
                (e: E){acc(
                  append<Type>(E, W),
                  <R: Type>{ 
                    (f: List2Fn<R, append<Type>(E, W)>){ w<[E]{R}>(
                      substr(
                        List2Fn<[E]{R}, W>, 
                        List2Fn<R, append<Type>(E, W)>,
                        prop_List2Fn_app<R, W, E>, 
                        f
                      ),
                      e
                    )}
                  }
                )}
              )
            }
          },
          L
        )(empty<Type>, id)
      }
    '''),
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
];
