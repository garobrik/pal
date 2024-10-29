# todo

## edit pal in pal

### technical reqs
  - migrations??? (i hope not)

### ergonomics
  - orderedmap for type trees
  - undo
  - add basic operations on core types
  - wrap with fn
  - editing records nicer
  - better fnexpr arg editor
  - follow the goal of specialized construct impls for different types:
    - create specific impl for editing exprs of type constructions
      - maybe need to update dispatch bleh
      - orrr can do this w functions?
  - make pal editor more concise
    - specialized construct impls for different types
  - deferred follower that fits itself into screen
  - better expr suggestions for placeholder
    - type driven
    - hide irrelevant bindings (probably via ModuleDef parameters)

### dream changes
  - memberhas typeprop is membershave
  - hierarchical binding ids

# media compendium use case
- tables with entries for:
  - title
  - kind
  - author/creator
  - rating
  - date finished
  - thoughts/review
  - genre
  - other metadata
- functionality
  - top level page/table selector
  - date column
  - filter on 
  
## need to make
- top level page/table selector
- select/multiselect column
- link column
- numeric column
- write to disk

# cooking use case
- recipes
  - list of {ingredient, quantity} pairs
  - directions paragraph
  - num servings
- pantry
  - link to ingredient
  - quantity
- ingredients table
  - vegan
  - GF
  - ~cost
  - nutrients
- shopping list table
  - link to ingredient
  - quantity
  - checkbox
- functionality:
  - multiply recipes
  - compute recipe nutrients
  - automatically add ingredients from recipe to shopping list
    - less pantry
  - filter recipes by:
    - ingredient
    - vegan/GF/etc

## need to make
- todo view
- page view
- culinary quantity column
- link column
- filter function


### HKT notes
interface Functor {
  t: ID,
  f: Type -> Type<id = t>,
  map: f(a) -> (a -> b)  -> f(b)
}


impl Functor {
  t: List,
  f: List.type, 
  map: List.type(a) -> (a -> b) -> List.type(b)
}

map: (a: Type, b: Type, t: ID, f: Type -> Type<id = t>, v: f(a), m: a -> b) -> f(b) {
  dispatch(Functor<t = t>).map(v, m)
}

map(v: List(int), m: (+1)):

m: a -> b assignable int -> int
a assignable int
b assignable int
v: Type<id = t> assignable List<int>
t assignable List.id
Functor.f: t assignable List<int>

----------------

interface Functor {
  f: Type -> Type,
  map: f(a) -> (a -> b)  -> f(b)
}

impl Functor {
  f: List.type
  
  map: List.type(a) -> (a -> b) -> List.type(b)
}

map: (a: Type, b: Type, f: Type -> Type, v: f(a), m: a -> b) -> f(b) {
  dispatch(Functor<f = f>).map(v, m)
}


assignable(Functor<f = List.type>, Functor<f = List.type>)

map(v: List(int), m: (+1)):

Functor.map((==0), [0])

a -> b assignable int -> bool
a assignable int
b assignable bool
f(int) assignable List<int>
returns: f(bool)


----------------

type TypeConstructor {
  base: Type,
  apply: Type -> Type<assignableTo base>,
}

impl Infer {
  to: TypeConstructor
}

interface Functor {
  f: TypeConstructor<...>,
  map: f(a) -> (a -> b)  -> f(b),
}

impl Functor {
  f: List.type,
  map: List.type(a) -> (a -> b) -> List.type(b),
}

map: (a: Type, b: Type, f: TypeConstructor, v: f(a), m: a -> b) -> f(b) {
  dispatch(Functor<f = f>).map(v, m)
}

map(v: List(int), m: (+1)):

a -> b assignable int -> int
a assignable int
b assignable int
f(int) assignable List<int>
b (with x = int) assignable List<elem = int>
b = List<elem = x>
