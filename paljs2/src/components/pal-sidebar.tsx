import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupAction,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenuButton,
  SidebarMenuItem,
} from '@/components/ui/sidebar';
import { createTable, selectTable } from '@/state/actions';
import { tables } from '@/state/table';
import { For } from '@legendapp/state/react';
import { Plus } from 'lucide-react';

export function AppSidebar() {
  return (
    <Sidebar collapsible="icon">
      <SidebarHeader>
        <h1>Pal</h1>
      </SidebarHeader>
      <SidebarContent>
        {/* <SidebarGroup>
          <SidebarGroupLabel>Docs</SidebarGroupLabel>
          <SidebarGroupAction>
            <Plus />
            <span className="sr-only">New Doc</span>
          </SidebarGroupAction>
          <SidebarGroupContent></SidebarGroupContent>
        </SidebarGroup> */}
        <SidebarGroup>
          <SidebarGroupLabel>Tables</SidebarGroupLabel>
          <SidebarGroupAction onClick={createTable}>
            <Plus /> <span className="sr-only">New Table</span>
          </SidebarGroupAction>
          <SidebarGroupContent>
            <For each={tables}>
              {(table) => (
                <SidebarMenuItem>
                  <SidebarMenuButton
                    asChild
                    onClick={() => selectTable(table.id.get())}
                  >
                    <a>{table.name.get()}</a>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              )}
            </For>
          </SidebarGroupContent>
        </SidebarGroup>
        {/* <SidebarGroup>
          <SidebarGroupLabel>Templates</SidebarGroupLabel>
          <SidebarGroupAction>
            <Plus />
            <span className="sr-only">New Template</span>
          </SidebarGroupAction>
          <SidebarGroupContent></SidebarGroupContent>
        </SidebarGroup> */}
      </SidebarContent>
      <SidebarFooter />
    </Sidebar>
  );
}
