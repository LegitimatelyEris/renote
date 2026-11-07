// The page editor: a Tiptap document that loads a note's Markdown as formatted text
// and writes it back as Markdown on every change. Text, headings, lists, checklists,
// quotes, code and dividers are edited directly; revision components (flashcards,
// definitions, quizzes, callouts, toggles, tables, images) sit in the page as cards
// that open a small source editor when clicked.
import {
  Editor, Node, Mark, Extension, mergeAttributes, markInputRule, StarterKit, Code, Highlight,
  TaskList, TaskItem, Placeholder, TextSelection,
} from './vendor/tiptap.js';
import { parse, renderInline, COLORS } from './markdown.js';

const cardViews = new Set(); // redraw hooks for component cards
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// ---------------------------------------------------------------- Markdown → HTML

/** Turns a note's Markdown into HTML the editor's schema understands. */
export function markdownToHtml(text) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  const blocks = parse(text);
  const out = [];
  const source = (s, e) => lines.slice(s, e + 1).join('\n');
  for (let i = 0; i < blocks.length; i++) {
    const b = blocks[i];
    switch (b.type) {
      case 'heading': out.push(`<h${b.level}>${renderInline(b.text)}</h${b.level}>`); break;
      case 'paragraph': out.push(`<p>${renderInline(b.text)}</p>`); break;
      case 'quote': out.push(`<blockquote>${b.text.split('\n').map(l => `<p>${renderInline(l)}</p>`).join('')}</blockquote>`); break;
      case 'code': out.push(`<pre><code${b.lang ? ` class="language-${esc(b.lang)}"` : ''}>${esc(b.text)}</code></pre>`); break;
      case 'divider': out.push('<hr>'); break;
      case 'list': out.push(listHtml(b.items, b.ordered)); break;
      default: {
        // Components keep their exact Markdown; consecutive definitions travel together.
        let end = b.end;
        if (b.type === 'definition') while (blocks[i + 1]?.type === 'definition') end = blocks[++i].end;
        out.push(`<div data-rn-block data-src="${esc(source(b.start, end))}"></div>`);
      }
    }
  }
  return out.join('') || '<p></p>';
}

function listHtml(items, ordered) {
  // Build nested lists from indentation; checklist items become task lists.
  let html = '';
  let i = 0;
  const level = items[0]?.indent ?? 0;
  while (i < items.length) {
    const task = items[i].checked !== null;
    const run = [];
    while (i < items.length && (items[i].indent > level || (items[i].checked !== null) === task)) {
      run.push(items[i]);
      i++;
      if (i < items.length && items[i].indent === level && (items[i].checked !== null) !== task) break;
    }
    const tag = task ? 'ul data-type="taskList"' : ordered ? 'ol' : 'ul';
    html += `<${tag}>`;
    for (let j = 0; j < run.length; j++) {
      const it = run[j];
      if (it.indent > level) continue;
      const children = [];
      while (run[j + 1] && run[j + 1].indent > level) children.push(run[++j]);
      const inner = `<p>${renderInline(it.text)}</p>${children.length ? listHtml(children, ordered) : ''}`;
      html += task ? `<li data-type="taskItem" data-checked="${it.checked}">${inner}</li>` : `<li>${inner}</li>`;
    }
    html += `</${tag.split(' ')[0]}>`;
  }
  return html;
}

// ---------------------------------------------------------------- Document → Markdown

const MARK_ORDER = ['link', 'color', 'gap', 'bold', 'italic', 'strike', 'highlight', 'underline', 'smallcaps', 'code'];

function delims(mark, prevChar) {
  switch (mark.type) {
    case 'bold': return ['**', '**'];
    case 'italic': return /\w/.test(prevChar || '') ? ['*', '*'] : ['_', '_'];
    case 'strike': return ['~~', '~~'];
    case 'highlight': return ['==', '=='];
    case 'underline': return ['++', '++'];
    case 'smallcaps': return ['^^', '^^'];
    case 'gap': return ['{{', '}}'];
    case 'code': return ['`', '`'];
    case 'color': return [`{${mark.attrs?.color || 'red'}|`, '}'];
    case 'link': return ['[', `](${mark.attrs?.href || ''})`];
  }
  return ['', ''];
}

/** Escapes characters that would otherwise turn into formatting when read back. */
function escapeText(t) {
  return t
    .replace(/\\/g, '\\\\')
    .replace(/([*`])/g, '\\$1')
    .replace(/(==|~~|\+\+|\^\^|\{\{|\}\})/g, m => '\\' + m[0] + m[1])
    .replace(/\{(\w+)\|/g, '\\{$1|')
    .replace(/(^|[^\w])_/g, '$1\\_')
    .replace(/\[([^\]]*)\]\(/g, '\\[$1](');
}

function inlineMd(nodes = []) {
  let out = '';
  const stack = []; // open marks, outermost first
  const key = m => m.type + (m.attrs ? JSON.stringify(m.attrs) : '');
  const close = () => {
    const m = stack.pop();
    const trail = /\s+$/.exec(out)?.[0] || '';
    out = out.slice(0, out.length - trail.length) + m.close + trail;
  };
  for (const n of nodes) {
    if (n.type === 'hardBreak') { while (stack.length) close(); out += ' '; continue; }
    if (n.type !== 'text') continue;
    const marks = (n.marks || []).slice().sort((a, b) => MARK_ORDER.indexOf(a.type) - MARK_ORDER.indexOf(b.type));
    // Close everything from the first open mark that this text no longer has.
    let keep = 0;
    while (keep < stack.length && keep < marks.length && stack[keep].key === key(marks[keep])) keep++;
    while (stack.length > keep) close();
    let text = n.text;
    const isCode = marks.some(m => m.type === 'code');
    for (const m of marks.slice(keep)) {
      const lead = /^\s+/.exec(text)?.[0] || '';
      out += lead;
      text = text.slice(lead.length);
      const [open, closeStr] = delims(m, out.at(-1));
      out += open;
      stack.push({ key: key(m), close: closeStr });
    }
    out += isCode ? text : escapeText(text);
  }
  while (stack.length) close();
  return out;
}

/** Stops a plain paragraph from being read back as a heading, list, quiz, etc. */
function guardLineStart(line) {
  if (/^(#{1,6} |[-*+] |\d+[.)] |> ?|\? |[QqAa]:|\||```|\+\+\+|!\[)/.test(line) || /^([-*_]\s*){3,}$/.test(line)) return '\\' + line;
  return line.replace(/ :: /g, ' \\:: ');
}

function listMd(node, depth, ordered) {
  const lines = [];
  let n = node.attrs?.start || 1;
  for (const item of node.content || []) {
    const pad = '  '.repeat(depth);
    let marker = ordered ? `${n++}. ` : '- ';
    if (item.type === 'taskItem') marker = `- [${item.attrs?.checked ? 'x' : ' '}] `;
    const [first, ...rest] = item.content || [];
    lines.push(pad + marker + (first?.type === 'paragraph' ? inlineMd(first.content) : ''));
    for (const child of rest) {
      if (['bulletList', 'orderedList', 'taskList'].includes(child.type)) lines.push(...listMd(child, depth + 1, child.type === 'orderedList'));
      else if (child.type === 'paragraph') lines.push(pad + '  ' + inlineMd(child.content));
    }
  }
  return lines;
}

export function docToMarkdown(doc) {
  const parts = [];
  for (const node of doc.content || []) {
    switch (node.type) {
      case 'heading': {
        const text = inlineMd(node.content);
        if (text.trim()) parts.push('#'.repeat(node.attrs.level) + ' ' + text);
        break;
      }
      case 'paragraph': {
        const text = inlineMd(node.content);
        if (text.trim()) parts.push(guardLineStart(text));
        break;
      }
      case 'bulletList': parts.push(listMd(node, 0, false).join('\n')); break;
      case 'orderedList': parts.push(listMd(node, 0, true).join('\n')); break;
      case 'taskList': parts.push(listMd(node, 0, false).join('\n')); break;
      case 'blockquote': parts.push((node.content || []).map(p => '> ' + inlineMd(p.content)).join('\n')); break;
      case 'codeBlock': parts.push('```' + (node.attrs?.language || '') + '\n' + (node.content || []).map(t => t.text).join('') + '\n```'); break;
      case 'horizontalRule': parts.push('---'); break;
      case 'rnBlock': if (node.attrs.src.trim()) parts.push(node.attrs.src.trim()); break;
    }
  }
  return parts.join('\n\n') + '\n';
}

// ---------------------------------------------------------------- Schema extensions

const Gap = Mark.create({
  name: 'gap',
  parseHTML: () => [{ tag: 'span.gap' }],
  renderHTML: ({ HTMLAttributes }) => ['span', mergeAttributes(HTMLAttributes, { class: 'gap' }), ['span', 0]],
  addInputRules() { return [markInputRule({ find: /(?:^|\s)(\{\{(?!\s)([^}]+)\}\})$/, type: this.type })]; },
  addKeyboardShortcuts() { return { 'Mod-Shift-g': () => this.editor.commands.toggleMark(this.name) }; },
});

const SmallCaps = Mark.create({
  name: 'smallcaps',
  parseHTML: () => [{ tag: 'span.caps' }],
  renderHTML: ({ HTMLAttributes }) => ['span', mergeAttributes(HTMLAttributes, { class: 'caps' }), 0],
  addInputRules() { return [markInputRule({ find: /(?:^|\s)(\^\^(?!\s)([^^]+)\^\^)$/, type: this.type })]; },
});

const ColorText = Mark.create({
  name: 'color',
  addAttributes: () => ({ color: { default: 'red', parseHTML: el => el.getAttribute('data-color') } }),
  parseHTML: () => [{ tag: 'span[data-color]' }],
  renderHTML: ({ HTMLAttributes }) => ['span', { 'data-color': HTMLAttributes.color, style: `color:${COLORS[HTMLAttributes.color] || 'inherit'}` }, 0],
});

const Underline2 = Mark.create({
  name: 'underline',
  parseHTML: () => [{ tag: 'u' }],
  renderHTML: () => ['u', 0],
  addKeyboardShortcuts() { return { 'Mod-u': () => this.editor.commands.toggleMark(this.name) }; },
  addInputRules() { return [markInputRule({ find: /(?:^|\s)(\+\+(?!\s)([^+]+)\+\+)$/, type: this.type })]; },
});

// ⌘E toggles View / Edit, so inline code gets ⌘⇧C instead.
const InlineCode = Code.extend({ addKeyboardShortcuts() { return { 'Mod-Shift-c': () => this.editor.commands.toggleCode() }; } });

/** A revision component card. Holds its own Markdown; edited through a small source box. */
function componentNode(renderComponent) {
  return Node.create({
    name: 'rnBlock',
    group: 'block',
    atom: true,
    draggable: true,
    selectable: true,
    addAttributes: () => ({ src: { default: '', parseHTML: el => el.getAttribute('data-src') || '' } }),
    parseHTML: () => [{ tag: 'div[data-rn-block]' }],
    renderHTML: ({ node }) => ['div', { 'data-rn-block': '', 'data-src': node.attrs.src }],
    addNodeView() {
      return ({ node, editor, getPos }) => {
        const dom = document.createElement('div');
        dom.className = 'rn-block';
        let current = node;
        let editing = false;
        const show = () => {
          editing = false;
          dom.classList.remove('editing-src');
          dom.innerHTML = '';
          const view = document.createElement('div');
          view.className = 'rn-view';
          dom.appendChild(view);
          renderComponent(current.attrs.src, view, editor.isEditable);
          if (editor.isEditable) {
            const hint = document.createElement('button');
            hint.className = 'rn-edit';
            hint.type = 'button';
            hint.textContent = 'Edit';
            dom.appendChild(hint);
          }
        };
        const openSource = (select) => {
          if (editing || !editor.isEditable) return;
          editing = true;
          dom.classList.add('editing-src');
          dom.innerHTML = '';
          const ta = document.createElement('textarea');
          ta.className = 'rn-src';
          ta.value = current.attrs.src;
          ta.spellcheck = true;
          const help = document.createElement('div');
          help.className = 'rn-help';
          help.textContent = 'Editing the Markdown for this card · Esc or click away to finish';
          dom.append(ta, help);
          const size = () => { ta.style.height = 'auto'; ta.style.height = ta.scrollHeight + 'px'; };
          size();
          ta.focus();
          if (select && select.start >= 0) ta.setSelectionRange(select.start, select.end);
          ta.oninput = size;
          const finish = (moveOn) => {
            if (!editing) return;
            const src = ta.value;
            const pos = getPos();
            editing = false;
            if (!src.trim()) {
              editor.chain().deleteRange({ from: pos, to: pos + current.nodeSize }).focus().run();
              return;
            }
            editor.view.dispatch(editor.state.tr.setNodeMarkup(pos, undefined, { src }));
            if (moveOn) {
              const after = pos + editor.state.doc.nodeAt(pos).nodeSize;
              editor.chain().focus().setTextSelection(Math.min(after + 1, editor.state.doc.content.size)).run();
            }
            show();
          };
          ta.onkeydown = e => {
            if (e.key === 'Escape' || ((e.metaKey || e.ctrlKey) && e.key === 'Enter')) { e.preventDefault(); finish(true); }
          };
          ta.onblur = () => finish(false);
        };
        dom.addEventListener('mousedown', e => {
          if (!editor.isEditable || editing) return;
          e.preventDefault();
          openSource();
        });
        dom._openSource = openSource;
        show();
        cardViews.add(show);
        return {
          destroy() { cardViews.delete(show); },
          dom,
          update(next) {
            if (next.type.name !== 'rnBlock') return false;
            current = next;
            if (!editing) show();
            return true;
          },
          stopEvent: e => editing || e.type === 'mousedown',
          ignoreMutation: () => true,
          selectNode() { dom.classList.add('selected'); },
          deselectNode() { dom.classList.remove('selected'); },
        };
      };
    },
  });
}

// ---------------------------------------------------------------- Slash menu & format bar

const SLASH_ITEMS = [
  { label: 'Text', icon: 'T', run: c => c.setParagraph() },
  { label: 'Title', icon: 'H1', run: c => c.setHeading({ level: 1 }) },
  { label: 'Section heading', icon: 'H2', run: c => c.setHeading({ level: 2 }) },
  { label: 'Sub-heading', icon: 'H3', run: c => c.setHeading({ level: 3 }) },
  { label: 'Bulleted list', icon: '•', run: c => c.toggleBulletList() },
  { label: 'Numbered list', icon: '1.', run: c => c.toggleOrderedList() },
  { label: 'Checklist', icon: '☐', run: c => c.toggleTaskList() },
  { label: 'Quote', icon: '❝', run: c => c.setBlockquote() },
  { label: 'Code block', icon: '</>', run: c => c.setCodeBlock() },
  { label: 'Divider', icon: '—', run: c => c.setHorizontalRule() },
  { label: 'Gap fill', icon: '▭', run: c => c.insertContent('<span class="gap"><span>answer</span></span>&nbsp;') },
  { label: 'Flashcard', icon: '⧉', card: 'Q: Question\nA: Answer', select: [3, 11] },
  { label: 'Definition', icon: '≡', card: 'Term :: What it means', select: [0, 4] },
  { label: 'Quiz', icon: '?', card: '? Question\n- ( ) Wrong answer\n- (x) Right answer\n- ( ) Wrong answer', select: [2, 10] },
  { label: 'Callout: Tip', icon: '!', card: '> [!tip] Tip\n> Write the key point here', select: [15, 39] },
  { label: 'Callout: Remember', icon: '!', card: '> [!remember] Remember\n> Write the key point here', select: [25, 49] },
  { label: 'Callout: Warning', icon: '!', card: '> [!warning] Watch out\n> Write the key point here', select: [25, 49] },
  { label: 'Callout: Example', icon: '!', card: '> [!example] Example\n> Write the example here', select: [23, 45] },
  { label: 'Toggle', icon: '▸', card: '+++ Click to expand\nHidden details\n+++', select: [4, 19] },
  { label: 'Table', icon: '▦', card: '| Column | Column |\n|---|---|\n| Cell | Cell |', select: [2, 8] },
  { label: 'Image', icon: '▣', card: '![Caption](image.png)', select: [12, 21] },
];

function slashPlugin() {
  return Extension.create({
    name: 'renoteSlash',
    addKeyboardShortcuts() {
      return {
        ArrowDown: () => slashMove(1),
        ArrowUp: () => slashMove(-1),
        Enter: () => slashPick(this.editor),
        Escape: () => { if (!slash) return false; closeSlash(); return true; },
      };
    },
  });
}

let slash = null; // { el, items, index, from, query }

function updateSlash(editor) {
  const { state } = editor;
  const { $from, empty } = state.selection;
  if (!empty || !editor.isEditable) return closeSlash();
  const parent = $from.parent;
  const textBefore = parent.textBetween(0, $from.parentOffset, '\n', '\n');
  const m = /^\/([\w ]{0,24})$/.exec(textBefore);
  if (!m || parent.type.name !== 'paragraph') return closeSlash();
  const q = m[1].toLowerCase().trim();
  const items = SLASH_ITEMS.filter(it => it.label.toLowerCase().includes(q));
  if (!slash) {
    slash = { el: document.createElement('div'), index: 0 };
    slash.el.className = 'slash';
    document.body.appendChild(slash.el);
    slash.el.addEventListener('mousedown', e => {
      e.preventDefault();
      const b = e.target.closest('[data-i]');
      if (b) { slash.index = +b.dataset.i; slashPick(editor); }
    });
  }
  slash.items = items;
  slash.from = $from.pos - textBefore.length;
  slash.to = $from.pos;
  slash.index = Math.min(slash.index, Math.max(0, items.length - 1));
  slash.el.innerHTML = items.length
    ? `<div class="slash-head">Insert</div>` + items.map((it, i) => `<button data-i="${i}" class="${i === slash.index ? 'on' : ''}"><span class="si">${esc(it.icon)}</span>${esc(it.label)}</button>`).join('')
    : '<div class="none">Nothing matches</div>';
  const at = editor.view.coordsAtPos(slash.from);
  slash.el.style.left = Math.min(at.left, innerWidth - 280) + 'px';
  const below = at.bottom + 8;
  slash.el.style.top = (below + 320 > innerHeight ? Math.max(12, at.top - 328) : below) + 'px';
  slash.el.querySelector('.on')?.scrollIntoView({ block: 'nearest' });
}

function closeSlash() { slash?.el.remove(); slash = null; return false; }
function slashMove(d) {
  if (!slash || !slash.items.length) return false;
  slash.index = (slash.index + d + slash.items.length) % slash.items.length;
  slash.el.querySelectorAll('button').forEach((b, i) => b.classList.toggle('on', i === slash.index));
  slash.el.querySelector('.on')?.scrollIntoView({ block: 'nearest' });
  return true;
}
function slashPick(editor) {
  if (!slash) return false;
  const item = slash.items[slash.index];
  const { from, to } = slash;
  closeSlash();
  if (!item) return true;
  const chain = editor.chain().focus().deleteRange({ from, to });
  if (item.card) {
    chain.insertContentAt(from, { type: 'rnBlock', attrs: { src: item.card } }).run();
    // Open the new card's source straight away with the placeholder selected.
    let at = -1, best = Infinity;
    editor.state.doc.descendants((node, pos) => {
      if (node.type.name === 'rnBlock' && node.attrs.src === item.card && Math.abs(pos - from) < best) { best = Math.abs(pos - from); at = pos; }
    });
    requestAnimationFrame(() => {
      const dom = at >= 0 ? editor.view.nodeDOM(at) : null;
      dom?._openSource?.({ start: item.select[0], end: item.select[1] });
    });
  } else {
    item.run(chain).run();
  }
  return true;
}

const COLOR_CHOICES = ['red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink'];

function bubbleBar(editor) {
  const bar = document.createElement('div');
  bar.className = 'bubble';
  bar.innerHTML = `
    <button data-m="bold" title="Bold (⌘B)"><b>B</b></button>
    <button data-m="italic" title="Italic (⌘I)"><i>I</i></button>
    <button data-m="underline" title="Underline (⌘U)"><u>U</u></button>
    <button data-m="strike" title="Strikethrough (⌘⇧S)"><s>S</s></button>
    <button data-m="highlight" title="Highlight (⌘⇧H)"><span class="hl">H</span></button>
    <button data-m="gap" title="Hide as a gap (⌘⇧G)"><span class="gp">Gap</span></button>
    <button data-m="code" title="Code (⌘⇧C)"><code>&lt;/&gt;</code></button>
    <button data-m="link" title="Link">↗</button>
    <span class="sep"></span>
    ${COLOR_CHOICES.map(c => `<button class="sw" data-c="${c}" title="${c}" style="--sw:${COLORS[c]}"></button>`).join('')}
    <button class="sw clear" data-c="" title="Default colour"></button>`;
  document.body.appendChild(bar);
  bar.addEventListener('mousedown', e => {
    e.preventDefault();
    const b = e.target.closest('button');
    if (!b) return;
    const c = editor.chain().focus();
    if (b.dataset.m === 'link') {
      const prev = editor.getAttributes('link').href || 'https://';
      const href = prompt('Link to', prev);
      if (href === null) return;
      href ? c.extendMarkRange('link').setLink({ href }).run() : c.extendMarkRange('link').unsetLink().run();
    } else if (b.dataset.m) c.toggleMark(b.dataset.m).run();
    else if (b.dataset.c !== undefined) b.dataset.c ? c.setMark('color', { color: b.dataset.c }).run() : c.unsetMark('color').run();
    position();
  });
  const position = () => {
    const { from, to, empty } = editor.state.selection;
    const inText = editor.state.selection instanceof TextSelection;
    if (empty || !inText || !editor.isEditable || !editor.isFocused) { bar.classList.remove('show'); return; }
    const a = editor.view.coordsAtPos(from), z = editor.view.coordsAtPos(to);
    const mid = (Math.min(a.left, z.left) + Math.max(a.right, z.right)) / 2;
    bar.classList.add('show');
    const w = bar.offsetWidth;
    bar.style.left = Math.max(8, Math.min(innerWidth - w - 8, mid - w / 2)) + 'px';
    bar.style.top = Math.max(8, Math.min(a.top, z.top) - bar.offsetHeight - 10) + 'px';
    bar.querySelectorAll('[data-m]').forEach(x => x.classList.toggle('on', editor.isActive(x.dataset.m)));
  };
  editor.on('selectionUpdate', position);
  editor.on('blur', () => setTimeout(() => { if (!editor.isFocused) bar.classList.remove('show'); }, 100));
  editor.on('focus', position);
  addEventListener('scroll', position, { passive: true });
  return { destroy: () => { bar.remove(); removeEventListener('scroll', position); } };
}

// ---------------------------------------------------------------- Create

/**
 * Mounts the page editor.
 * renderComponent(src, el, editable) draws a component card into `el`.
 * onChange(markdown) is called (debounced) after edits.
 */
export function createPageEditor({ element, text, editable, renderComponent, onChange, onToggleCheck }) {
  let timer;
  const editor = new Editor({
    element,
    editable,
    content: markdownToHtml(text),
    extensions: [
      StarterKit.configure({ code: false, underline: false, link: { openOnClick: false, autolink: true }, heading: { levels: [1, 2, 3, 4, 5, 6] } }),
      InlineCode,
      Underline2,
      Highlight.extend({ addKeyboardShortcuts() { return { 'Mod-Shift-h': () => this.editor.commands.toggleHighlight() }; } }),
      TaskList,
      TaskItem.configure({ nested: true, onReadOnlyChecked: (node, checked) => { onToggleCheck?.(); return true; } }),
      Gap, SmallCaps, ColorText,
      componentNode(renderComponent),
      slashPlugin(),
      Placeholder.configure({
        includeChildren: false,
        showOnlyCurrent: false,
        placeholder: ({ editor, node, pos, hasAnchor }) => {
          if (node.type.name === 'heading' && node.attrs.level === 1) return 'Untitled';
          if (node.type.name === 'heading') return hasAnchor ? 'Heading' : '';
          const doc = editor.state.doc;
          const lastOfShortNote = doc.childCount <= 2 && pos + node.nodeSize === doc.content.size;
          if (pos === 0) return 'Start with a title…';
          return hasAnchor || lastOfShortNote ? 'Write something, or type / for flashcards, quizzes and more' : '';
        },
      }),
    ],
    onUpdate: ({ editor }) => {
      updateSlash(editor);
      clearTimeout(timer);
      timer = setTimeout(() => onChange(docToMarkdown(editor.getJSON())), 250);
    },
    onSelectionUpdate: ({ editor }) => updateSlash(editor),
    onBlur: () => setTimeout(closeSlash, 150),
  });
  const bubble = bubbleBar(editor);
  const flush = () => { clearTimeout(timer); onChange(docToMarkdown(editor.getJSON())); };
  return {
    editor,
    flush,
    setEditable(on) {
      editor.setEditable(on);
      // Re-draw cards so they switch between interactive (View) and editable (Edit).
      cardViews.forEach(show => show());
    },
    destroy() { clearTimeout(timer); bubble.destroy(); closeSlash(); editor.destroy(); },
  };
}
