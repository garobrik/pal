import { monaco } from './monaco';
import Editor from '@monaco-editor/react';
import initSwc, { transformSync } from '@swc/wasm-web';
import { createElement, useCallback, useEffect, useRef, useState } from 'react';
import { Column, Row } from './Components';

type Cursor<T> = {
  get: () => T;
  set: (t: T) => void;
};

type ObjCursor<T extends object> = Cursor<T> & {
  [K in keyof T]: Cursor<T>;
};

type Node<T> = {
  state: T;
  renderNode: React.FC<Cursor<T>>;
};

const DEFAULT_SRC = '<h1>PalJS!</h1>';

const render = (src: string) => {
  const result = transformSync(src, {
    filename: 'hello.tsx',
    jsc: {
      parser: {
        syntax: 'typescript',
        tsx: true,
      },
      transform: {
        react: {
          pragma: 'createElement',
        },
      },
    },
  });
  return eval(`(createElement) => ${result.code}`)(createElement);
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
(initSwc as any)();
const App = () => {
  const [rendered, setRendered] = useState<React.ReactNode>(
    render(DEFAULT_SRC)
  );
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null);
  useEffect(() =>
    window.onresize?.((() => {
      editorRef.current?.layout();
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
    }) as any)
  );

  const onValidate = useCallback(async (arr: monaco.editor.IMarker[]) => {
    if (arr.length !== 0) return;
    const value = monaco.editor
      .getModel(monaco.Uri.parse('hello.tsx'))
      ?.getValue();
    if (value) {
      setRendered(render(value));
    }
  }, []);

  console.log(rendered);

  return (
    <Column flex={1} padding={20}>
      <h1>PalJS!</h1>
      <Row flex={1}>
        <Column flex={1}>
          <Editor
            defaultLanguage="typescript"
            defaultValue={DEFAULT_SRC}
            defaultPath="hello.tsx"
            width="50vw"
            theme="vs-dark"
            options={{
              lineNumbers: 'off',
              minimap: { enabled: false },
              scrollbar: { vertical: 'hidden', horizontal: 'hidden' },
              lineDecorationsWidth: 0,
              automaticLayout: true,
              overviewRulerLanes: 0,
            }}
            onValidate={onValidate}
            onMount={(editor) => (editorRef.current = editor)}
          />
        </Column>
        {rendered}
      </Row>
    </Column>
  );
};

export default App;
