import { Node } from '../nodes';
import { RenderNode } from '../RenderNode';
import { Cursor, ID } from '../types';

export type Image = {
  nodes: Record<ID, Node>;
  home: ID;
};

export const Home = ({ state }: { state: Cursor<Image> }) => {
  return <RenderNode node={state.nodes[state.home.get()]} />;
};
