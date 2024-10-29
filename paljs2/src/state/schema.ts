import { newID } from '@/state/id';

export type FieldConstraint = (obj: unknown) => boolean;

export type SchemaField = {
  id: string;
  type: string;
  meta: unknown;
  constraints: FieldConstraint[];
};

export type FieldSchema = {
  id: string;
  name: string;
};

export const stringSchema = {
  id: 'f312d1c4-829b-4f9b-8718-9f584a2f903f',
  name: 'string',
};
export const fieldSchemas = [stringSchema];

export type Schema = {
  fields: SchemaField[];
};

export const defaultSchema = (): Schema => ({
  fields: [
    {
      id: newID(),
      type: stringSchema.id,
      meta: {},
      constraints: [],
    },
  ],
});
