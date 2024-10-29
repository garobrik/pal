import { defaultSchema, Schema } from '@/state/schema';
import { createTableObserver } from '@/state/state';
import { newID } from '@/state/id';

export type Table = {
  id: string;
  name: string;
  schema: Schema;
  rows: Record<string, unknown>;
};

export const tables = createTableObserver<Table>('tables');

export const defaultTable = (): Table => {
  const id = newID();

  return { id, name: 'New Table', schema: defaultSchema(), rows: {} };
};
