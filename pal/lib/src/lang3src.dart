import 'lang3.dart';

class Binding {
  final ID id;
  final String source;

  const Binding(this.id, this.source);
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
  Binding('Boolean', '''
    FnType(R)(Type)(FnType(t)(R)(FnType(f)(R)(R)))
  '''),
  Binding('true', '''
    FnDef(R)(Type)(FnDef(t)(R)(FnDef(f)(R)(t)))
  '''),
  Binding('false', '''
    FnDef(R)(Type)(FnDef(t)(R)(FnDef(f)(R)(f)))
  '''),
  Binding('if', '''
    FnDef(R)(Type)(FnDef(b)(Boolean)(FnDef(t)(R)(FnDef(f)(R)(b(R)(t)(f)))))
  '''),
];
