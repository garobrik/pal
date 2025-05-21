import * as Y from 'yjs';
import { IndexeddbPersistence } from 'y-indexeddb';
import { useCallback, useEffect, useState } from 'react';
import { appState } from '@/state/app';
import { newID } from '@/state/id';
import { useY } from 'react-yjs';
import { useYMapKey } from '@/state/yjsUtils';
import { WebrtcProvider } from 'y-webrtc';

const syncProvider = (id: string, doc: Y.Doc, password: string) => {
  return new WebrtcProvider(id, doc, {
    signaling: ['wss://pal-signaling.fly.dev'],
    password,
  });
};

const userIndex = new Y.Doc();
const persistence = new IndexeddbPersistence('userIndex', userIndex);
syncProvider(appState.userID.peek(), userIndex, appState.userPassword.peek());
const docIDs = userIndex.getArray<DocID>('docIDs');

type DocID = {
  id: string;
  password: string;
};

type DocMeta = {
  title: string;
};

export type Doc = {
  id: string;
  meta: Y.Map<unknown>;
  content: Y.XmlFragment;
};

export const getDocKeys = () => {
  return docIDs.map((d) => d.id);
};

export const useDocKeys = () => {
  return useY(docIDs).map((d) => d.id);
};

type DocHolder = {
  id: string;
  password: string;
  doc: Doc;
  ydoc: Y.Doc;
  persistence: IndexeddbPersistence;
  ready: () => boolean;
  onReady: (cb: () => void) => () => void;
};

const docs = new Map<string, DocHolder>();

const initializeDoc = (id: string, password: string): DocHolder => {
  if (docs.has(id)) {
    return docs.get(id)!;
  }

  const ydoc = new Y.Doc();
  const doc = {
    id,
    content: ydoc.getXmlFragment('content'),
    meta: ydoc.getMap('meta'),
  };
  const persistence = new IndexeddbPersistence(id, ydoc);
  syncProvider(id, ydoc, password);
  const docHolder: DocHolder = {
    id,
    password,
    doc,
    ydoc,
    persistence,
    ready: () => persistence.synced,
    onReady: (cb: () => void) => {
      const listener = () => {
        cb();
        persistence.off('synced', listener);
      };
      persistence.on('synced', listener);
      return () => persistence.off('synced', listener);
    },
  };

  docs.set(id, docHolder);
  return docHolder;
};

export const getDocPassword = (id: string) => {
  return docIDs.toArray().find((d) => d.id === id)!.password;
}

export const useDoc = (id: string) => {
  const pw = getDocPassword(id);
  const docHolder = initializeDoc(id, pw);

  const [ready, setReady] = useState(docHolder.ready());
  const onReady = useCallback(() => {
    setReady(true);
  }, []);

  useEffect(() => docHolder.onReady(onReady), [docHolder, docHolder.onReady, onReady]);

  if (ready) {
    return docHolder.doc;
  } else {
    return 'loading';
  }
};

export const useDocMetaField = <K extends keyof DocMeta>(doc: Doc, key: K) => {
  return useYMapKey<DocMeta, K>(doc.meta, key);
};

export const selectDoc = (id: string) => {
  appState.selectedDoc.set(id);
};

export const importDoc = (id: string, pw: string) => {
  const docHolder = initializeDoc(id, pw);
  docIDs.push([{ id: docHolder.id, password: docHolder.password }]);
  docHolder.onReady(() => selectDoc(docHolder.id));
};

export const createDoc = () => {
  const docHolder = initializeDoc(newID(), newID());

  docHolder.doc.meta.set('title', 'Untitled document');
  docIDs.push([{ id: docHolder.id, password: docHolder.password }]);
  selectDoc(docHolder.id);
};

export const useIsReady = () => {
  const [ready, setReady] = useState(userIndex.isLoaded);
  useEffect(() => {
    const listener = () => {
      setReady(true);
      persistence.off('synced', listener);
    };
    persistence.on('synced', listener);
    return () => {
      persistence.off('synced', listener);
    };
  }, []);
  return ready;
};
