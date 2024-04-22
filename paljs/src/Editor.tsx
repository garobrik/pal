import { Editor as MonacoEditor } from '@monaco-editor/react';
import { useCallback, useEffect, useRef } from 'react';
import { monaco } from './monaco';

type EditorProps = {
  filename: string;
  initialValue: string;
  onChange: (value: string) => void;
};
export const Editor = ({ initialValue, filename, onChange }: EditorProps) => {
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null);
  useEffect(() =>
    window.onresize?.((() => {
      editorRef.current?.layout();
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
    }) as any)
  );

  const onValidate = useCallback(
    async (arr: monaco.editor.IMarker[]) => {
      if (arr.length !== 0) return;
      const value = monaco.editor
        .getModel(monaco.Uri.parse(`${filename}.tsx`))
        ?.getValue();
      if (value) {
        onChange(value);
      }
    },
    [onChange, filename]
  );

  return (
    <MonacoEditor
      defaultLanguage="typescript"
      defaultValue={initialValue}
      path={filename}
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
  );
};
