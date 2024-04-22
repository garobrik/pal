import { Cursor } from '../types';
import { Column as ColumnComponent } from '../Components';
import { For } from '@legendapp/state/react';
import { RenderNode } from '../RenderNode';

export type ColumnState = {
  children: Node[];
};
export const Column = ({ state }: { state: Cursor<ColumnState> }) => {
  return (
    <ColumnComponent rowGap={10}>
      <For<Node, Record<string, never>> each={state.children}>
        {(child) => <RenderNode node={child} />}
      </For>
    </ColumnComponent>
  );
};
