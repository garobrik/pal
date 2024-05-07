# refl type

```
<T: _1, v: T> [ Eq<_2>(v, v) ]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  unify typeof _1 <-> Type
    _1: Type
  introduce T: _1

<T: _1, v: T> [ Eq<_2>(v, v) ]
        ^^^^^^^^^^^^^^^^^^^^^^

  unify typeof T = _1 <-> Type
    _1 = Type
  introduce v: T

<T: _1, v: T> [ Eq<_2>(v, v) ]
                ^^^^^^^^^^^^

<T: _1, v: T> [ Eq<_2>(v, v) ]
                ^^^^^^^^

<T: _1, v: T> [ Eq<_2>(v, v) ]
                ^^^^^^

<T: _1, v: T> [ Eq<_2>(v, v) ]
                ^^

<T: _1, v: T> [ <T: Type>(T1: T, T2: T)[Type]<_2>(v, v) ]
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  unify Type <-> typeof _2
    _2: Type

<T: _1, v: T> [ (T1: _2, T2: _2)[Type](v, v) ]
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  unify _2 <-> T
    T = _2
```

# prop_nat_0

```

<Result: Type, initial: Result, step: (Result)[Result]>[
  Eq<Result>(apply<Result>(initial, step, zero), initial)
]
  <_1: _1t, _2: _2t, _3: _3t>{ refl<_4, _5> }
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    unify typeof _1t <> Type
      _1t: Type
    introduce _1: _1t

  <_1: _1t, _2: _2t, _3: _3t>{ refl<_4, _5> }
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    unify typeof _2t <> Type
      _2t: Type
    introduce _2: _2t

  <_1: _1t, _2: _2t, _3: _3t>{ refl<_4, _5> }
                     ^^^^^^^^^^^^^^^^^^^^^^^^
    unify typeof _3t <> Type
      _3t: Type
    introduce _3: _3t

  <_1: _1t, _2: _2t, _3: _3t>{ refl<_4, _5> }
                               ^^^^^^^^^^^^

  <_1: _1t, _2: _2t, _3: _3t>{ refl<_4, _5> }
                               ^^^^^^^^

  <_1: _1t, _2: _2t, _3: _3t>{ refl<_4, _5> }
                               ^^^^

  <_1: _1t, _2: _2t, _3: _3t>[ <T: Type, v: T> [ Eq<T>(v, v) ]<_4, _5> ]
                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    unify typeof _4 = Type
      _4: Type

  <_1: _1t, _2: _2t, _3: _3t>[ <v: T> [ Eq<_4>(v, v) ]<_5> ]
                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^
    unify typeof _5 = T
      _5: T

unify:
  <Result: Type, initial: Result, step: (Result)[Result]>[
    Eq<Result>(apply<Result>(initial, step, zero), initial)
  ]
  <_1: _1t, _2: _2t, _3: _3t>[ Eq<_4>(_5, _5) ]
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  unify Type <> _1t
    _1t = Type

  <initial: Result, step: (Result)[Result]>[
    Eq<Result>(apply<Result>(initial, step, zero), initial)
  ]
  <_1: _1t, _2: _2t, _3: _3t>[ Eq<_4>(_5, _5) ]
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  unify _2t <> Result
    _2t = Result

  <step: (Result)[Result]>[
    Eq<Result>(apply<Result>(initial, step, zero), initial)
  ]
  <Result: Type, initial: Result, _3: _3t>[ Eq<_4>(_5, _5) ]
                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^

  unify _3t <> (Result)[Result]
    _3t = (Result)[Result]

  Eq<Result>(apply<Result>(initial, step, zero), initial)
  <Result: Type, initial: Result, step: (Result)[Result]>[ Eq<_4>(_5, _5) ]
                                                           ^^^^^^^^^^^^^^

  unify Result <> _4
    _4 = Result

  Eq<Result>(apply<Result>(initial, step, zero), initial)
  <Result: Type, initial: Result, step: (Result)[Result]>[ Eq<Result>(_5, _5) ]
                                                                     ^^^^^^^^

  unify apply<Result>(initial, step, zero) <> _5
    _5 = apply<Result>(initial, step, zero)

  Eq<Result>(apply<Result>(initial, step, zero), initial)
  <Result: Type, initial: Result, step: (Result)[Result]>[
    Eq<Result>(
      apply<Result>(initial, step, zero),
      apply<Result>(initial, step, zero)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    )
  ]

  unify apply<Result>(initial, step, zero) <> initial
    can't unify!
```
