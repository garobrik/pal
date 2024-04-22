import { useCallback } from 'react';
import { Cursor } from '../types';

export const Header = ({ state }: { state: Cursor<string> }) => {
  const onInput = useCallback(
    (ev: React.FormEvent) => state.set(ev.currentTarget.textContent),
    [state]
  );
  return (
    <h1 contentEditable onInput={onInput}>
      {state.get()}
    </h1>
  );
};
