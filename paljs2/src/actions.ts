import { appState } from "@/state/app";
import { getDocPassword } from "@/state/docs";


export const linkDeviceURL = () => {
  navigator.clipboard.writeText(
    `${
      window.location.origin
    }/#/linkDevice?id=${appState.userID.peek()}&pw=${appState.userPassword.peek()}`
  );

  alert('Link URL copied to clipboard. Paste it into different browser to link that device.');
};


export const shareDocURL = () => {
  const id = appState.selectedDoc.peek();
  if (id === null) {
    return;
  }

  navigator.clipboard.writeText(
    `${
      window.location.origin
    }/#/doc?id=${id}&pw=${getDocPassword(id)}`
  );

  alert('Share URL copied to clipboard. Paste it into different browser to open this document on that device.');
};
