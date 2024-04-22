import { nodeKinds, Node } from './nodes';
import { Cursor } from './types';

export const RenderNode = ({ node }: { node: Cursor<Node> }) => {
  const Render = nodeKinds[node.kind.get()];
  return <Render state={node.state as never} />;
};
