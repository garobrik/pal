import { defaultTable, tables } from '@/state/table';
import { appState } from '@/state/app';

export const selectTable = (id: string) => {
  appState.selectedEntity.set(id);
};

export const createTable = () => {
  const table = defaultTable();

  tables.assign({
    [table.id]: table,
  });

  appState.selectedEntity.set(table.id);

  return table;
};
