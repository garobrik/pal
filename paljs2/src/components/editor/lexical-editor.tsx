import { AutoFocusPlugin } from '@lexical/react/LexicalAutoFocusPlugin';
import { CheckListPlugin } from '@lexical/react/LexicalCheckListPlugin';
import { ClearEditorPlugin } from '@lexical/react/LexicalClearEditorPlugin';
import { ClickableLinkPlugin } from '@lexical/react/LexicalClickableLinkPlugin';
import { CollaborationPlugin } from '@lexical/react/LexicalCollaborationPlugin';
import { LexicalErrorBoundary } from '@lexical/react/LexicalErrorBoundary';
import { HashtagPlugin } from '@lexical/react/LexicalHashtagPlugin';
import { HorizontalRulePlugin } from '@lexical/react/LexicalHorizontalRulePlugin';
import { ListPlugin } from '@lexical/react/LexicalListPlugin';
import { RichTextPlugin } from '@lexical/react/LexicalRichTextPlugin';
import { TabIndentationPlugin } from '@lexical/react/LexicalTabIndentationPlugin';
import { TablePlugin } from '@lexical/react/LexicalTablePlugin';

import { createWebrtcProvider } from './collaboration';
import { LexicalComposer } from '@lexical/react/LexicalComposer';
import { ContentEditable } from '@lexical/react/LexicalContentEditable';
import { TableCellNode, TableNode, TableRowNode } from '@lexical/table';
import { HashtagNode } from '@lexical/hashtag';
import { ListItemNode, ListNode } from '@lexical/list';

export const Editor = ({ id }: { id: string }) => {
  const initialConfig = {
    editorState: null,
    namespace: 'editor',
    nodes: [
      TableNode,
      HashtagNode,
      ListNode,
      ListItemNode,
      TableCellNode,
      TableRowNode,
    ],
    onError: console.error,
  };

  return (
    <LexicalComposer key={id} initialConfig={initialConfig}>
      <CollaborationPlugin
        key={id}
        id={id}
        providerFactory={createWebrtcProvider}
        shouldBootstrap={true}
      />
      <AutoFocusPlugin />
      <ClearEditorPlugin />
      <HashtagPlugin />
      <RichTextPlugin
        contentEditable={<ContentEditable />}
        ErrorBoundary={LexicalErrorBoundary}
      />
      <ListPlugin />
      <CheckListPlugin />
      <TablePlugin hasCellMerge hasCellBackgroundColor />
      <ClickableLinkPlugin />
      <HorizontalRulePlugin />
      <TabIndentationPlugin />
    </LexicalComposer>
  );
};
