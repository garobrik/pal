import { useEffect, useState } from 'react';
import { ProseMirror } from '@nytimes/react-prosemirror';
import { EditorState } from 'prosemirror-state';
import {
  initProseMirrorDoc,
  ySyncPlugin,
  yUndoPlugin,
  undo,
  redo,
} from 'y-prosemirror';
import { schema } from 'prosemirror-schema-basic';
import { keymap } from 'prosemirror-keymap';
import { exampleSetup } from 'prosemirror-example-setup';
import { Doc, useDoc } from '@/state/docs';
import { Skeleton } from '../ui/skeleton';

const initializeState = (doc: Doc) => {
  const xml = doc.content;
  const { doc: pmDoc, mapping } = initProseMirrorDoc(xml, schema);
  return EditorState.create({
    doc: pmDoc,
    schema,
    plugins: [
      ySyncPlugin(xml, { mapping }),
      yUndoPlugin(),
      keymap({
        'Mod-z': undo,
        'Mod-y': redo,
      }),
    ].concat(exampleSetup({ schema, menuBar: false })),
  });
};

export const EditorContent = ({ doc }: { doc: Doc }) => {
  // It's important that mount is stored as state,
  // rather than a ref, so that the ProseMirror component
  // is re-rendered when it's set
  const [mount, setMount] = useState<HTMLElement | null>(null);
  const [state, setState] = useState<EditorState>(initializeState(doc));
  useEffect(() => {
    setState(initializeState(doc));
  }, [doc]);

  return (
    <ProseMirror
      mount={mount}
      state={state}
      dispatchTransaction={(tr) => setState((s) => s.apply(tr))}
    >
      <div className="w-full h-full outline-none" ref={setMount} />
    </ProseMirror>
  );
};

export const Editor = ({ id }: { id: string }) => {
  const doc = useDoc(id);
  if (doc === 'loading') return <Skeleton />;
  return <EditorContent doc={doc} />;
};
