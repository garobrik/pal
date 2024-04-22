import { Column } from './Column';
import { Header } from './Header';
import { Home } from './Home';

export type Node = {
  state: unknown;
  kind: NodeKind;
};

type NodeKind = keyof NodeKinds;
type NodeKinds = typeof nodeKinds;

export const nodeKinds = {
  Home,
  Column,
  Header,
};
