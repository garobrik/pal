import { Node } from './nodes';
import { Column } from './Components';
import { useObservable } from '@legendapp/state/react';
import { RenderNode } from './RenderNode';

const newRootNode = (): Node => ({
  state: {
    nodes: {
      home: {
        kind: 'Header',
        state: 'PalJS!',
      },
    },
    home: 'home',
  },
  kind: 'Home',
});

const App = () => {
  const rootNode = useObservable(newRootNode());
  rootNode.onChange(console.log);

  return (
    <Column flex={1} padding={20}>
      <RenderNode node={rootNode} />
    </Column>
  );
};

export default App;
