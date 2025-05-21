import { observable } from '@legendapp/state';
import { ObservablePersistLocalStorage } from '@legendapp/state/persist-plugins/local-storage';
import { syncObservable } from '@legendapp/state/sync';
import { newID } from '@/state/id';

type AppState = {
  selectedDoc: string | null;
  userID: string;
  userPassword: string;
};

export const appState = observable<AppState>({
  selectedDoc: null,
  userID: newID(),
  userPassword: newID(),
});

syncObservable(appState, {
  persist: {
    name: 'settings',
    plugin: ObservablePersistLocalStorage,
  },
});
