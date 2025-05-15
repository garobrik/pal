import { Memo, Show } from '@legendapp/state/react';
import { AppSidebar } from '@/components/app-sidebar';
import { appState } from '@/state/app';
import { Editor } from '@/components/editor/editor';
import { useIsReady } from '@/state/docs';

function App() {
  if (!useIsReady()) {
    return null;
  }
  return (
    <AppSidebar>
      <main className="p-4 flex-1">
        <Show if={() => appState.selectedDoc.get() != null}>
          <Memo>{() => <Editor id={appState.selectedDoc.get()!} />}</Memo>
        </Show>
      </main>
    </AppSidebar>
  );
}

export default App;
