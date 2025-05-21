import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarInset,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarTrigger,
  useSidebar,
} from '@/components/ui/sidebar';
import { Link, Plus, Share2 } from 'lucide-react';
import { Separator } from '@/components/ui/separator';
import { Show } from '@legendapp/state/react';
import { appState } from '@/state/app';
import { linkDeviceURL, shareDocURL } from '@/actions';
import { useCallback } from 'react';
import {
  useDoc,
  Doc,
  useDocMetaField,
  useDocKeys,
  createDoc,
  selectDoc,
} from '@/state/docs';
import { Skeleton } from './ui/skeleton';
import { Button } from './ui/button';

const DocMenuItemContent = ({ doc }: { doc: Doc }) => {
  const [title] = useDocMetaField(doc, 'title');
  const sidebar = useSidebar();
  const onClick = useCallback(() => {
    selectDoc(doc.id);
    if (sidebar.isMobile) {
      sidebar.toggleSidebar();
    }
  }, [sidebar, doc.id]);

  return (
    <SidebarMenuItem key={doc.id}>
      <SidebarMenuButton asChild onClick={onClick} className="cursor-pointer">
        <a>{title}</a>
      </SidebarMenuButton>
    </SidebarMenuItem>
  );
};

const DocMenuItem = ({ id }: { id: string }) => {
  const doc = useDoc(id);
  if (doc === 'loading') return <Skeleton />;
  return <DocMenuItemContent doc={doc} />;
};

const DocTitleContent = ({ doc }: { doc: Doc }) => {
  const [title, setTitle] = useDocMetaField(doc, 'title');
  return (
    <input
      className="text-xl border-none outline-none flex-1"
      value={title}
      onChange={(ev) => setTitle(() => ev.target.value)}
    />
  );
};

const DocTitle = ({ id }: { id: string }) => {
  const doc = useDoc(id);
  if (doc === 'loading') return <div className="flex-1"><Skeleton className="w-40" /></div>;
  return <DocTitleContent doc={doc} />;
};

export const ShareDocButton = () => {
  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={shareDocURL}
    >
      <Share2 />
    </Button>
  );
};

export function AppSidebar({ children }: React.PropsWithChildren) {
  const keys = useDocKeys();
  return (
    <SidebarProvider>
      <Sidebar collapsible="offcanvas">
        <SidebarHeader>
          <h1>Pal</h1>
        </SidebarHeader>
        <SidebarContent>
          <SidebarGroup>
            <SidebarMenuButton onClick={linkDeviceURL}>
              <Link/> Link Device
            </SidebarMenuButton>
          </SidebarGroup>
          <SidebarGroup>
            <SidebarGroupLabel className="justify-between">
              <h2>Docs</h2>
              <Button variant="ghost" size="icon" onClick={createDoc}>
                <Plus />
                <span className="sr-only">New Doc</span>
              </Button>
            </SidebarGroupLabel>
            <SidebarGroupContent>
              {keys.map((docID) => (
                <DocMenuItem key={docID} id={docID} />
              ))}
            </SidebarGroupContent>
          </SidebarGroup>
        </SidebarContent>
        <SidebarFooter />
      </Sidebar>
      <SidebarInset>
        <header className="flex justify-between items-center shrink-0 gap-2 border-b p-2">
          <SidebarTrigger className="-ml-1" />
          <Show if={() => appState.selectedDoc.get() != null}>
            {() => (
              <>
                <Separator orientation="vertical" className="mr-2 h-4" />
                <DocTitle id={appState.selectedDoc.get()!} />
              </>
            )}
          </Show>
          <ShareDocButton />
        </header>
        {children}
      </SidebarInset>
    </SidebarProvider>
  );
}
