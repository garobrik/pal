import { Memo, Reactive, Show } from '@legendapp/state/react';
import { AppSidebar } from './components/pal-sidebar';
import { SidebarProvider } from './components/ui/sidebar';
import { appState } from './state/app';
import { tables } from './state/table';

function App() {
  return (
    <SidebarProvider>
      <AppSidebar />
      <main className="p-4">
        <Show if={() => appState.selectedEntity.get() != null}>
          <Memo>
            {() => (
              <Reactive.input
                className="text-xl font-semibold"
                $value={tables[appState.selectedEntity.get()!].name}
              />
            )}
          </Memo>
        </Show>
        <h1></h1>
      </main>
    </SidebarProvider>
  );
}

export default App;
