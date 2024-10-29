import { observable } from '@legendapp/state';
import { observablePersistIndexedDB } from '@legendapp/state/persist-plugins/indexeddb';
import { configureSynced } from '@legendapp/state/sync';

const tableNames = ['tables'] as const;
type TableName = (typeof tableNames)[number];

const persistOptions = configureSynced({
  persist: {
    plugin: observablePersistIndexedDB({
      databaseName: 'pal',
      version: 1,
      tableNames: [...tableNames],
    }),
  },
});

export const createTableObserver = <T extends { id: string }>(
  name: TableName
) => observable<Record<string, T>>(persistOptions({ persist: { name } }));
