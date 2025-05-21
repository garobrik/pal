import { appState } from "@/state/app";
import { importDoc } from "@/state/docs";

export const initialize = () => {
  if (window.location.hash.startsWith('#/linkDevice')) {
    const userID = window.location.hash.match(/id=([^&]+)/);
    const password = window.location.hash.match(/pw=([^&]+)/);
    if (userID && password) {
      appState.userID.set(userID[1]);
      appState.userPassword.set(password[1]);
    }
    window.history.replaceState(null, '', window.location.origin);
  }
  
  if (window.location.hash.startsWith('#/doc')) {
    const doc = window.location.hash.match(/id=([^&]+)/);
    const password = window.location.hash.match(/pw=([^&]+)/);
    if (doc && password) {
      importDoc(doc[1], password[1]);
    }
    window.history.replaceState(null, '', window.location.origin);
  }
};
