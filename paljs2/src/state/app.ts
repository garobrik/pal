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

if (window.location.pathname === '/linkDevice') {
  const userID = window.location.search.match(/id=([^&]+)/);
  const password = window.location.search.match(/pw=([^&]+)/);
  if (userID && password) {
    appState.userID.set(userID[1]);
    appState.userPassword.set(password[1]);
  }
  window.location.href = window.location.origin;
}

if (window.location.pathname === '/doc') {
  const doc = window.location.search.match(/id=([^&]+)/);
  const password = window.location.search.match(/pw=([^&]+)/);
  if (doc && password) {
    // appState.userID.set(doc[1]);
    // appState.userPassword.set(password[1]);
  }
  window.location.href = window.location.origin;
}

export const linkDeviceURL = () => {
  console.log(
    `${
      window.location.origin
    }/linkDevice?id=${appState.userID.peek()}&pw=${appState.userPassword.peek()}`
  );
};
