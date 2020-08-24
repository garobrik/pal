# Lens<T, S>
LensResult<List<S>> get(T);
LensResult<T> over(T t, (S) f(S));
Lens<T, S1> then(Lens<S, S1> other)
  - Lens(
      get: (t) => {
        res = this.get(t);
        results = zip(res.children, res.result).fold(LensResult([], [], []), (acc, p) {
          subres = other.get(p.b);
          return LensResult(
            acc.children + subres.children.map((child) => p.a + child), 
            subres.consts + acc.consts, 
            acc.result + subres.result,
          );
        });
      },
      over: (t, f1) => this.over(t, (s) => other.over(s, f1)),
    )

# LensResult<A>
final List<String> children;
final Set<String> consts;
final A result;

# StateManager<T>
- set(lens, val)

# FocusedLens<T, S>
final StateManager<T> focus;
final Lens<T, S> lens;
S get();
set(S val);
over(S f(S));
FocusedLens<T, S1> operator >(Lens<S, S1> other);

# Clazz
final A f1;
final int f2;

# $Clazz
eq, hashCode, etc

# abstract class CursorOps
# abstract class GetOps
# abstract class SetOps

# abstract class GetSet<A> extends CursorOps, GetOps, SetOps
# abstract class Get<A> extends CursorOps, GetOps
# abstract class Set extends CursorOps, SetOps



# extension Clazz$<T, F extends CursorOps> on Cursor<T, Clazz, F>
Clazz$(Lens<T, Clazz>);

# extension Clazz$<T, F extends GetOps> on Cursor<T, Clazz, F>

# abstract class K<C, T>
C constructor();

# abstract class ViewComposerConstructor
final ViewComposer<ViewComposerConstructor> composer();

# abstract class ViewComposer<C extends ViewComposerConstructor>
K<C, S1> thenView<S, S1>(K<C, S> composer, View<S, S1> view);

# extension HigherViewComposer<C extends ComposerWitness, S> on K<C, S>
K<C, S1> thenView(View<S, S1> view) => this.constructor().composer().thenView(this, view);

# extension Clazz$<C extends LensComposerWitness> on K<C, Clazz>
Lens<Clazz, S1> $f1;
K<C, S1> get f1 => this.then(f1);
