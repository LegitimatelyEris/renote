// Everything Renote's page editor needs from Tiptap, bundled into public/vendor/tiptap.js.
export { Editor, Node, Mark, Extension, mergeAttributes, markInputRule, markPasteRule, InputRule } from '@tiptap/core';
export { default as StarterKit } from '@tiptap/starter-kit';
export { Code } from '@tiptap/extension-code';
export { Highlight } from '@tiptap/extension-highlight';
export { TaskList, TaskItem } from '@tiptap/extension-list';
export { Placeholder } from '@tiptap/extensions';
export { TextSelection, NodeSelection } from '@tiptap/pm/state';
