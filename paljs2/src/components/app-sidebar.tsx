import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupAction,
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
import { Plus, Share } from 'lucide-react';
import { Separator } from '@/components/ui/separator';
import { Show } from '@legendapp/state/react';
import { appState, linkDeviceURL } from '@/state/app';
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
      <SidebarMenuButton asChild onClick={onClick}>
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
      className="text-xl"
      value={title}
      onChange={(ev) => setTitle(() => ev.target.value)}
    />
  );
};

const DocTitle = ({ id }: { id: string }) => {
  const doc = useDoc(id);
  if (doc === 'loading') return <Skeleton />;
  return <DocTitleContent doc={doc} />;
};

const LinkDeviceButton = () => {
  return (
    <Button
      variant="ghost"
      size="icon"
      className="h-7 w-7"
      onClick={() => {
        linkDeviceURL();
      }}
    >
      <Share />
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
            <SidebarGroupLabel>Docs</SidebarGroupLabel>
            <SidebarGroupAction onClick={createDoc}>
              <Plus />
              <span className="sr-only">New Doc</span>
            </SidebarGroupAction>
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
        <header className="flex items-center shrink-0 gap-2 border-b p-2">
          <SidebarTrigger className="-ml-1" />
          <Show if={() => appState.selectedDoc.get() != null}>
            {() => (
              <>
                <Separator orientation="vertical" className="mr-2 h-4" />
                <DocTitle id={appState.selectedDoc.get()!} />
              </>
            )}
          </Show>
          <div className="flex-1" />
          <LinkDeviceButton />
        </header>
        {children}
      </SidebarInset>
    </SidebarProvider>
  );
}
