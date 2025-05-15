import { useCallback } from 'react';
import { useY } from 'react-yjs';
import * as Y from 'yjs';

type KeyUpdater<T> = <K extends keyof T>(
  key: keyof T & string,
  value: T[K]
) => void;

export const useYMap = <T extends object>(
  map: Y.Map<unknown>
): [T, KeyUpdater<T>] => {
  const current = useY(map);
  const setter = useCallback<KeyUpdater<T>>(
    (key, value) => {
      map.set(key, value);
    },
    [map]
  );
  return [current as T, setter];
};

type ValueUpdater<T> = (f: (_: T) => T) => void;

export const useYMapKey = <T extends object, K extends keyof T & string>(
  map: Y.Map<unknown>,
  key: K
): [T[K], ValueUpdater<T[K]>] => {
  const [current, updateKey] = useYMap<T>(map);
  const updater = useCallback<ValueUpdater<T[K]>>(
    (f) => {
      updateKey(key, f((map.get(key) as T)[key]));
    },
    [updateKey, key, map]
  );
  return [current[key], updater];
};
