import { Memo, Show } from '@legendapp/state/react';
import { AppSidebar } from '@/components/app-sidebar';
import { appState } from '@/state/app';
import { Editor } from '@/components/editor/editor';
import { useIsReady } from '@/state/docs';
import { initialize } from '@/initialize';
import { useEffect } from 'react';
import { Loader2 } from 'lucide-react';

function App() {
  const isReady = useIsReady();
  useEffect(() => {
    if (isReady) {
      initialize();
    }
  }, [isReady]);

  if (!isReady) {
    return <div className="flex flex-col pt-[33%] items-center"><Loader2 className="absolute left-auto top-1/3 animate-spin" /></div>;
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
