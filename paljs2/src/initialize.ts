import { appState } from "@/state/app";
import { importDoc } from "@/state/docs";

export const initialize = () => {
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
      importDoc(doc[1], password[1]);
    }
    window.location.href = window.location.origin;
  }
};
