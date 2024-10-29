## web UI

- tailwind
- radix
- shadcn

## web rich editing

- https://news.ycombinator.com/item?id=31813550
- https://discuss.prosemirror.net/t/differences-between-prosemirror-and-lexical/4557/7
- notion's is private

### needs

- mobile support
- non-trivial layout
- can integrate with 3rd party data model (two way data binding?)
  - read how y-prosemirror is impl'd
- readonly rendering
- static/server-side rendering

### libs

#### blocksuite

- heavily opinionated architecture, harder to figure out how to implement custom functionality
- focused on notion-like block editing model rather than specifically richtext

#### prosemirror

related:

- remirror
- react-prosemirror
- tiptap

#### slatejs

- react based
- unopinionated/easy to understand data model
- helpful/easy to understand examples
- poor mobile support

#### lexical

- made by facebook
- react based
- heavily prosemirror inspired
