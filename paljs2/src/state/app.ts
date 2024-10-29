import { observable } from '@legendapp/state';

type AppState = {
  selectedEntity: string | null;
};

export const appState = observable<AppState>({
  selectedEntity: null,
});
