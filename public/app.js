import { parse, renderInline, plain, studyCards, CALLOUTS } from './markdown.js';
import { createPageEditor } from './doc.js';

// ---------- Icons (simple line icons) ----------
const P = {
  book: '<path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2z"/><path d="M4 19V5"/>',
  pen: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13 7 4 4"/>',
  cards: '<rect x="3" y="7" width="14" height="13" rx="2"/><path d="M7 4h12a2 2 0 0 1 2 2v11"/>',
  folder: '<path d="M3 6a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
  file: '<path d="M6 3h8l5 5v13H6z"/><path d="M14 3v5h5"/>',
  grid: '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>',
  chart: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  up: '<path d="M12 19V5M6 11l6-6 6 6"/>',
  chev: '<path d="m9 6 6 6-6 6"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
  check: '<path d="m5 12 5 5L20 7"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  flip: '<path d="M4 12a8 8 0 0 1 14-5.3L20 9M20 4v5h-5M20 12a8 8 0 0 1-14 5.3L4 15M4 20v-5h5"/>',
  trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
  edit: '<path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>',
  bold: '<path d="M7 5h6a3.5 3.5 0 0 1 0 7H7zM7 12h7a3.5 3.5 0 0 1 0 7H7z"/>',
  italic: '<path d="M10 5h8M6 19h8M14 5l-4 14"/>',
  mark: '<path d="m9 11-6 6v3h9l3-3"/><path d="m22 12-4.6 4.6a2 2 0 0 1-2.8 0l-5.2-5.2a2 2 0 0 1 0-2.8L14 4"/>',
  eye: '<path d="M3 3l18 18M10.6 10.6a2 2 0 0 0 2.8 2.8M9.9 4.2A10 10 0 0 1 12 4c6 0 9 8 9 8a17 17 0 0 1-3 4.2M6.6 6.6C3.9 8.6 3 12 3 12s3 8 9 8a9.7 9.7 0 0 0 5.4-1.6"/>',
  dict: '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20V3H6.5A2.5 2.5 0 0 0 4 5.5z"/><path d="M8 7h8M8 11h5"/>',
  quiz: '<path d="M9 6h11M9 12h11M9 18h11"/><path d="m3 6 1 1 2-2M3 12l1 1 2-2M3 18l1 1 2-2"/>',
  bubble: '<path d="M21 12a8 8 0 0 1-11.6 7.1L3 21l1.9-6.4A8 8 0 1 1 21 12z"/>',
  toggle: '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="m10 8 4 4-4 4"/>',
  table: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18M9 4v16"/>',
  code: '<path d="m8 8-4 4 4 4M16 8l4 4-4 4"/>',
  todo: '<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-5"/>',
  lines: '<path d="M4 6h16M4 12h10M4 18h14"/>',
  bulb: '<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.7.7 1 1.5 1 2.5h6c0-1 .3-1.8 1-2.5A6 6 0 0 0 12 3z"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>',
  alert: '<circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16.5v.5"/>',
  triangle: '<path d="M12 4 2.5 20h19z"/><path d="M12 10v4M12 17v.5"/>',
  flame: '<path d="M12 22a7 7 0 0 0 7-7c0-4-3-6-4-10-2 2-3 4-3 6-1-1-2-2-2-4-2 2-5 5-5 8a7 7 0 0 0 7 7z"/>',
  list: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.7M12 17v.5"/>',
  brain: '<path d="M9 4a3 3 0 0 0-3 3 3 3 0 0 0-2 5 3 3 0 0 0 2 5 3 3 0 0 0 6 1V5a2 2 0 0 0-3-1zM15 4a3 3 0 0 1 3 3 3 3 0 0 1 2 5 3 3 0 0 1-2 5 3 3 0 0 1-6 1"/>',
  pencil: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
  arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/>',
};
const icon = (name, size = 15) => `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${P[name] || ''}</svg>`;
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const $ = sel => document.querySelector(sel);

// ---------- State ----------
const state = { notes: [], subjects: [], folder: '', log: [], path: null, text: '', saved: '', search: '' };
let saveTimer = null;

const api = {
  async get(url) { const r = await fetch(url); if (!r.ok) throw new Error((await r.json()).error); return r.json(); },
  async send(method, url, data) {
    const r = await fetch(url, { method, headers: { 'content-type': 'application/json' }, body: JSON.stringify(data) });
    const json = await r.json();
    if (!r.ok) throw new Error(json.error || 'Request failed');
    return json;
  },
};

function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toast.t);
  toast.t = setTimeout(() => t.classList.remove('show'), 1800);
}

async function loadIndex() {
  const data = await api.get('/api/notes');
  Object.assign(state, { notes: data.notes, subjects: data.subjects, folder: data.folder });
  state.log = await api.get('/api/log').catch(() => []);
}

async function openNote(path) {
  if (state.path === path) return;
  await saveNow();
  const data = await api.get('/api/note?path=' + encodeURIComponent(path));
  state.path = path;
  state.text = state.saved = data.text;
}

function setText(text, { render = true } = {}) {
  state.text = text;
  markDirty();
  clearTimeout(saveTimer);
  saveTimer = setTimeout(saveNow, 600);
  if (render) route();
}

async function saveNow() {
  clearTimeout(saveTimer);
  if (!state.path || state.text === state.saved) return;
  const text = state.text;
  const note = await api.send('PUT', '/api/note', { path: state.path, text });
  state.saved = text;
  const i = state.notes.findIndex(n => n.path === note.path);
  if (i >= 0) state.notes[i] = note;
  markDirty();
  renderSidebar();
}

function markDirty() {
  const el = document.querySelector('.save-state');
  if (!el) return;
  const dirty = state.text !== state.saved;
  el.classList.toggle('dirty', dirty);
  el.lastChild.textContent = dirty ? 'Saving…' : 'Saved';
}

const current = () => state.notes.find(n => n.path === state.path);
const timeAgo = ms => {
  const s = (Date.now() - ms) / 1000;
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  if (s < 86400 * 30) return `${Math.floor(s / 86400)}d ago`;
  return new Date(ms).toLocaleDateString();
};
const noteHref = (path, mode = 'read') => `#/note/${encodeURIComponent(path)}${mode === 'read' ? '' : '/' + mode}`;

// ---------- Routing ----------
function parseHash() {
  const h = location.hash.replace(/^#\/?/, '');
  const [kind, a, b] = h.split('/');
  if (kind === 'note' && a) return { view: 'note', path: decodeURIComponent(a), mode: b || 'read' };
  if (kind === 'subject' && a) return { view: 'home', subject: decodeURIComponent(a) };
  if (kind === 'progress') return { view: 'progress' };
  if (kind === 'revise') return { view: 'revise-all' };
  return { view: 'home' };
}

async function route() {
  const r = parseHash();
  if (r.view !== 'note' && pageEditor) { pageEditor.flush(); pageEditor.destroy(); pageEditor = null; }
  document.querySelectorAll('.links a').forEach(a => a.classList.toggle('active',
    (a.dataset.nav === 'home' && (r.view === 'home' || r.view === 'note')) || a.dataset.nav === r.view || (a.dataset.nav === 'revise' && r.view === 'revise-all')));
  if (r.view === 'note') {
    try { await openNote(r.path); } catch { location.hash = '#/'; return; }
  }
  renderSidebar(r);
  renderAnnounce();
  const main = $('#main');
  if (r.view === 'note') renderNote(main, r.mode);
  else if (r.view === 'progress') renderProgress(main);
  else if (r.view === 'revise-all') renderReviseHub(main);
  else renderHome(main, r.subject);
  observeReveals();
}

// ---------- Announcement bar ----------
function renderAnnounce() {
  const lastRevised = {};
  for (const e of state.log) lastRevised[e.path] = Math.max(lastRevised[e.path] || 0, Date.parse(e.at));
  const due = state.notes.filter(n => !lastRevised[n.path] || Date.now() - lastRevised[n.path] > 7 * 86400e3);
  const el = $('#announce');
  if (!state.notes.length) { el.innerHTML = ''; return; }
  const next = due[0];
  el.innerHTML = next
    ? `<span class="tag">Due for revision</span><a href="${noteHref(next.path, 'revise')}">${due.length === 1 ? esc(next.title) + " hasn't been revised this week" : `${due.length} notes haven't been revised this week`} ${icon('arrow', 14)}</a>`
    : `<span class="tag">On track</span><span>Every note has been revised this week. Nice.</span>`;
}

// ---------- Sidebar ----------
function renderSidebar(r = parseHash()) {
  const count = s => state.notes.filter(n => n.subject === s).length;
  const loose = state.notes.filter(n => !n.subject);
  const recents = [...state.notes].sort((a, b) => b.modified - a.modified).slice(0, 5);
  const item = (href, ic, label, on, extra = '', cls = '') =>
    `<a class="side-item ${cls} ${on ? 'on' : ''}" href="${href}">${icon(ic)}<span class="title">${esc(label)}</span>${extra}</a>`;
  const inProgress = r.view === 'progress';
  $('#sidebar').innerHTML = `
    <a class="workspace" href="#/"><span class="logo"><svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true"><path d="M6 5h8a5 5 0 0 1 0 10h-3l5 5" stroke="currentColor" stroke-width="2.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg></span>Renote<span class="count">${state.notes.length} notes</span></a>
    <div class="segment"><a href="#/" class="${inProgress ? '' : 'on'}">Notes</a><a href="#/progress" class="${inProgress ? 'on' : ''}">Progress</a></div>
    ${item('#/', 'grid', 'All notes', r.view === 'home' && !r.subject, `<span class="count">${state.notes.length}</span>`)}
    ${item('#/revise', 'cards', 'Revise', r.view === 'revise-all')}
    ${item('#/progress', 'chart', 'Progress', inProgress)}
    <div class="side-head">Subjects <button id="new-subject" title="New subject">${icon('plus', 14)}</button></div>
    ${state.subjects.map(s => item(`#/subject/${encodeURIComponent(s)}`, 'folder', s, r.subject === s || (r.view === 'note' && current()?.subject === s), `<span class="count">${count(s)}</span>`)).join('')}
    ${loose.length ? item('#/subject/' + encodeURIComponent('~'), 'file', 'Unsorted', r.subject === '~', `<span class="count">${loose.length}</span>`) : ''}
    <div class="side-head">Recents</div>
    ${recents.map(n => item(noteHref(n.path), 'bubble', n.title, n.path === state.path && r.view === 'note', '', 'recent')).join('')}
  `;
  $('#new-subject').onclick = () => newSubjectPrompt();
}

// ---------- Home ----------
function renderHome(main, subject) {
  const q = state.search.toLowerCase();
  let notes = state.notes;
  if (subject) notes = notes.filter(n => (subject === '~' ? !n.subject : n.subject === subject));
  if (q) notes = notes.filter(n => (n.title + ' ' + n.preview).toLowerCase().includes(q));
  const title = q ? `Results for “${esc(state.search)}”` : subject ? (subject === '~' ? 'Unsorted' : esc(subject)) : 'Your notes';
  const groups = subject || q ? [[null, notes]] : [...state.subjects.map(s => [s, notes.filter(n => n.subject === s)]), ['~', notes.filter(n => !n.subject)]].filter(([, ns]) => ns.length);
  const cell = n => {
    return `<a class="cell" href="${noteHref(n.path)}" data-path="${esc(n.path)}">
      <div class="k"><span>${esc(n.subject || 'Unsorted')}</span><span>${timeAgo(n.modified)}</span></div>
      <h3>${esc(n.title)}</h3><p>${esc(n.preview || 'Empty note')}</p>
      <div class="foot">${icon('chev', 13)} Open</div></a>`;
  };
  main.innerHTML = `
    <section class="hero">
      <div class="eyebrow"><span>${notes.length} ${notes.length === 1 ? 'note' : 'notes'}</span><span class="dot"></span><span>${state.subjects.length} subjects</span></div>
      <h2 class="big reveal">${title}</h2>
      <p class="lede">Write in plain Markdown, read it beautifully, then turn it into a deck of cards and test yourself.</p>
      <div class="bar"><div class="chips">
        <a class="chip ${!subject ? 'on' : ''}" href="#/">${icon('grid', 14)}All</a>
        ${state.subjects.map(s => `<a class="chip ${subject === s ? 'on' : ''}" href="#/subject/${encodeURIComponent(s)}">${icon('folder', 14)}${esc(s)}</a>`).join('')}
      </div>
      <div class="right"><button class="btn btn-white" data-new="${subject && subject !== '~' ? esc(subject) : ''}">${icon('plus', 14)} New note${subject && subject !== '~' ? ' in ' + esc(subject) : ''}</button></div></div>
    </section>
    ${groups.map(([s, ns]) => `
      ${groups.length > 1 ? `<div class="group-head">${icon('folder', 14)}<b>${esc(s === '~' ? 'Unsorted' : s)}</b><span>${ns.length}</span></div>` : ''}
      <div class="cells">${ns.map(cell).join('')}
        ${!q ? `<button class="cell new" data-new="${s && s !== '~' ? esc(s) : ''}">${icon('plus', 18)}<span>New note${s && s !== '~' ? ' in ' + esc(s) : ''}</span></button>` : ''}
      </div>`).join('')}
    ${!notes.length ? `<div class="empty">${q ? 'Nothing matches that search.' : 'No notes here yet.'}</div>` : ''}
  `;
  main.querySelectorAll('[data-new]').forEach(b => b.onclick = () => newNote(b.dataset.new || null));
}

async function newNote(subject = null) {
  const note = await api.send('POST', '/api/note', { subject });
  await loadIndex();
  location.hash = noteHref(note.path, 'edit');
}

// ---------- Note view: one page you can read or edit in place ----------
// Modes (in the URL): '' = page in view mode, 'edit' = same page editable,
// 'revise' = card deck, 'source' (or old 'write') = raw Markdown.
const EDIT_KEY = 'renote-editing';

let pageEditor = null; // the live document for the open note

function renderNote(main, mode) {
  const note = current();
  if (!note) { location.hash = '#/'; return; }
  if (mode === 'write') mode = 'source';
  pageEditor?.destroy();
  pageEditor = null;
  const blocks = parse(state.text);
  const cards = studyCards(blocks);
  const words = state.text.split(/\s+/).filter(Boolean).length;
  const editing = mode === 'edit';
  const head = `
    <div class="page-meta">
      ${note.subject ? `<a href="#/subject/${encodeURIComponent(note.subject)}">${esc(note.subject)}</a><span class="dot"></span>` : ''}
      <span>${Math.max(1, Math.round(words / 200))} min read</span><span class="dot"></span>
      <span>Edited ${timeAgo(note.modified)}</span>
      ${cards.length ? `<span class="dot"></span><a class="accent" href="${noteHref(note.path, 'revise')}">${cards.length} to revise</a>` : ''}
    </div>`;

  if (mode === 'revise') {
    main.innerHTML = `<article class="page-wrap">${head}<h1 class="page-title-small">${esc(note.title)}</h1></article><section class="revise" id="revise"></section>`;
  } else if (mode === 'source') {
    main.innerHTML = `<article class="page-wrap">${head}</article>` + writeView();
  } else {
    main.innerHTML = `<article class="page-wrap ${editing ? 'editing' : ''}" id="page-wrap">${head}<div class="page doc" id="page"></div></article>`;
  }
  main.insertAdjacentHTML('beforeend', dockHtml(note, mode, cards.length));
  wireDock(note, mode);

  if (mode === 'source') wireWrite();
  else if (mode === 'revise') startRevise($('#revise'), cards, note);
  else mountPage(editing);
}

/** Mounts the note as a live document: read-only in View, typed into directly in Edit. */
function mountPage(editing) {
  const page = $('#page');
  pageEditor = createPageEditor({
    element: page,
    text: state.text,
    editable: editing,
    renderComponent: (src, el, editable) => {
      el.innerHTML = blocksHtml(parse(src));
      // Cards are measured for flipping, so wire them once they're on screen.
      if (!editable) setTimeout(() => wireBlocks(el), 0);
    },
    onChange: md => { if (md !== state.text) setText(md, { render: false }); },
  });
  // Gaps reveal on click while reading.
  page.addEventListener('click', e => {
    const gap = e.target.closest('.gap');
    if (gap && !pageEditor?.editor.isEditable) gap.classList.toggle('open');
  });
  // Double-click anywhere while reading to start editing right there.
  page.addEventListener('dblclick', e => {
    if (pageEditor?.editor.isEditable) return;
    const at = pageEditor.editor.view.posAtCoords({ left: e.clientX, top: e.clientY });
    setEditing(true, at?.pos);
  });
  // Clicking the empty space under the text puts the cursor at the end.
  $('#page-wrap').addEventListener('mousedown', e => {
    if (!pageEditor?.editor.isEditable || e.target.closest('.ProseMirror, .page-meta, a, button')) return;
    e.preventDefault();
    pageEditor.editor.commands.focus('end');
  });
  if (editing) {
    const ed = pageEditor.editor;
    const first = ed.state.doc.firstChild;
    // A brand-new note opens with its title selected, ready to type over.
    if (first?.type.name === 'heading' && /^Untitled( \d+)?$/.test(first.textContent) && ed.state.doc.childCount <= 2) {
      ed.chain().focus().setTextSelection({ from: 1, to: 1 + first.content.size }).run();
    } else ed.commands.focus('start', { scrollIntoView: false });
  }
  observeReveals();
}

/** Flips the open page between View and Edit without reloading it. */
function setEditing(on, pos) {
  const r = parseHash();
  if (r.view !== 'note') return;
  sessionStorage.setItem('renote-flip', JSON.stringify({ pos: pos ?? null }));
  location.hash = noteHref(r.path, on ? 'edit' : 'read');
}

// ---------- Corner dock: View / Edit, type settings, revise, more ----------
function dockHtml(note, mode, cardCount) {
  const editing = mode === 'edit';
  return `<div class="dock" id="dock">
    <div class="dock-seg" role="tablist" aria-label="View or edit">
      <a href="${noteHref(note.path)}" class="${mode === 'read' ? 'on' : ''}" title="View (⌘E)">${icon('book', 14)}View</a>
      <a href="${noteHref(note.path, 'edit')}" class="${editing ? 'on' : ''}" title="Edit (⌘E)">${icon('pen', 14)}Edit</a>
    </div>
    <span class="dock-sep"></span>
    <button class="dock-btn" id="type-btn" title="Fonts and layout">Aa</button>
    <a class="dock-btn ${mode === 'revise' ? 'on' : ''}" href="${noteHref(note.path, 'revise')}" title="Revise this note">${icon('cards', 15)}${cardCount ? `<span class="badge">${cardCount}</span>` : ''}</a>
    <div class="menu" id="more-menu"><button class="dock-btn" id="more-btn" title="More">${icon('lines', 15)}</button>
      <div class="list-menu up">
        <button data-act="focus">${icon('grid')} ${document.body.classList.contains('focus') ? 'Show sidebar' : 'Hide sidebar'} <kbd>⌘\\</kbd></button>
        <button data-act="source">${icon('code')} ${mode === 'source' ? 'Back to page' : 'Edit as Markdown'}</button>
        <button data-act="rename">${icon('edit')} Rename</button>
        <button data-act="trash">${icon('trash')} Move to trash</button>
      </div>
    </div>
  </div>`;
}

function wireDock(note, mode) {
  $('#type-btn').onclick = e => { e.stopPropagation(); toggleTypePanel(); };
  const menu = $('#more-menu');
  $('#more-btn').onclick = e => { e.stopPropagation(); menu.classList.toggle('open'); };
  menu.querySelectorAll('[data-act]').forEach(b => b.onclick = async () => {
    menu.classList.remove('open');
    const act = b.dataset.act;
    if (act === 'focus') toggleFocus();
    else if (act === 'source') location.hash = noteHref(note.path, mode === 'source' ? 'read' : 'source');
    else if (act === 'rename') {
      const name = prompt('Rename note', note.path.split('/').pop().replace(/\.\w+$/, ''));
      if (!name) return;
      await saveNow();
      try {
        const { path } = await api.send('POST', '/api/note/rename', { path: note.path, name });
        await loadIndex();
        state.path = path;
        location.hash = noteHref(path, mode);
      } catch (err) { toast(err.message); }
    } else if (act === 'trash') {
      if (!confirm(`Move “${note.title}” to the trash? It is kept in .renote/trash inside your notes folder.`)) return;
      await saveNow();
      await api.send('POST', '/api/note/trash', { path: note.path });
      state.path = null;
      await loadIndex();
      location.hash = '#/';
      toast('Moved to trash');
    }
  });
}

function toggleFocus() {
  document.body.classList.toggle('focus');
  try { localStorage.setItem('renote-focus', document.body.classList.contains('focus') ? '1' : ''); } catch {}
  reportNoDrag();
}

function toggleEdit() {
  const r = parseHash();
  if (r.view !== 'note') return;
  setEditing(r.mode !== 'edit');
}

// ---------- Type settings ----------
const FONTS = [
  { name: 'Inter', css: "Inter, system-ui, sans-serif", note: 'Clean sans' },
  { name: 'Geist', css: "Geist, system-ui, sans-serif", note: 'Modern sans' },
  { name: 'Space Grotesk', css: "'Space Grotesk', system-ui, sans-serif", note: 'Quirky sans' },
  { name: 'Atkinson Hyperlegible', css: "'Atkinson Hyperlegible', system-ui, sans-serif", note: 'Extra readable' },
  { name: 'Newsreader', css: "Newsreader, Georgia, serif", note: 'Editorial serif' },
  { name: 'Literata', css: "Literata, Georgia, serif", note: 'Book serif' },
  { name: 'Fraunces', css: "Fraunces, Georgia, serif", note: 'Soft display serif' },
  { name: 'Instrument Serif', css: "'Instrument Serif', Georgia, serif", note: 'Elegant headlines' },
  { name: 'JetBrains Mono', css: "'JetBrains Mono', ui-monospace, monospace", note: 'Monospace' },
  { name: 'IBM Plex Mono', css: "'IBM Plex Mono', ui-monospace, monospace", note: 'Typewriter' },
  { name: 'Caveat', css: "Caveat, cursive", note: 'Handwritten' },
];
const ACCENTS = { orange: '#f97316', amber: '#f59e0b', lime: '#84cc16', green: '#22c55e', teal: '#14b8a6', blue: '#3b82f6', violet: '#8b5cf6', pink: '#ec4899', red: '#ef4444', white: '#e5e5e5' };
const DEFAULT_TYPE = { head: 'Inter', body: 'Inter', size: 17, width: 720, leading: 1.7, accent: 'orange', bg: '#0a0a0b', bgAlpha: 0.72, blur: 30 };
// Window colours to start from; any colour works through the picker.
const WINDOW_COLORS = ['#0a0a0b', '#1c1c1e', '#0f172a', '#1e1b4b', '#2e1065', '#3b0a24', '#052e2b', '#14261b', '#3a2a0a', '#5c4a1e'];
let typeSettings = { ...DEFAULT_TYPE };
const loadedFonts = new Set(['Inter', 'JetBrains Mono']);

function loadFont(name) {
  if (loadedFonts.has(name)) return;
  loadedFonts.add(name);
  const family = name.replace(/ /g, '+');
  const axes = name === 'Instrument Serif' || name === 'Caveat' ? '' : ':wght@400;500;600;700';
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = `https://fonts.googleapis.com/css2?family=${family}${name === 'Instrument Serif' ? ':ital@0;1' : axes}&display=swap`;
  document.head.appendChild(link);
}

function applyType() {
  const t = typeSettings;
  const font = n => (FONTS.find(f => f.name === n) || FONTS[0]).css;
  loadFont(t.head); loadFont(t.body);
  const root = document.documentElement.style;
  root.setProperty('--font-head', font(t.head));
  root.setProperty('--font-body', font(t.body));
  root.setProperty('--fs', t.size + 'px');
  // The last step of the Width slider means "use the whole window".
  root.setProperty('--measure', t.width >= 1500 ? '100%' : t.width + 'px');
  root.setProperty('--leading', t.leading);
  root.setProperty('--accent', ACCENTS[t.accent] || ACCENTS.orange);
  // Window tint, and in the Mac app the blur of the desktop behind it.
  root.setProperty('--win-bg', t.bg || DEFAULT_TYPE.bg);
  root.setProperty('--win-alpha', String(t.bgAlpha ?? DEFAULT_TYPE.bgAlpha));
  window.webkit?.messageHandlers?.renote?.postMessage({ window: { blur: Number(t.blur ?? DEFAULT_TYPE.blur) } });
}

let typeSaveTimer;
function saveType() {
  applyType();
  clearTimeout(typeSaveTimer);
  typeSaveTimer = setTimeout(() => api.send('PUT', '/api/settings', { type: typeSettings }).catch(() => {}), 400);
}

function toggleTypePanel() {
  const open = $('#type-panel');
  if (open) { open.remove(); return; }
  FONTS.forEach(f => loadFont(f.name));
  const panel = document.createElement('div');
  panel.id = 'type-panel';
  panel.className = 'type-panel';
  const fontList = which => FONTS.map(f => `<button class="font-opt ${typeSettings[which] === f.name ? 'on' : ''}" data-font="${which}|${esc(f.name)}" style="font-family:${esc(f.css)}">
      <span class="fn">${esc(f.name)}</span><span class="fd">${esc(f.note)}</span></button>`).join('');
  panel.innerHTML = `
    <div class="tp-head"><span>Look</span><button class="link" id="tp-reset">Reset</button></div>
    <div class="tp-tabs"><button class="on" data-tab="head">Headings</button><button data-tab="body">Body</button></div>
    <div class="font-list" data-list="head">${fontList('head')}</div>
    <div class="font-list" data-list="body" hidden>${fontList('body')}</div>
    <label class="tp-row"><span>Size</span><input type="range" min="14" max="22" step="1" id="tp-size" value="${typeSettings.size}"><b id="tp-size-v">${typeSettings.size}px</b></label>
    <label class="tp-row"><span>Width</span><input type="range" min="560" max="1500" step="20" id="tp-width" value="${typeSettings.width}"><b id="tp-width-v">${typeSettings.width >= 1500 ? 'Full' : typeSettings.width}</b></label>
    <label class="tp-row"><span>Spacing</span><input type="range" min="1.4" max="2.1" step="0.05" id="tp-lead" value="${typeSettings.leading}"><b id="tp-lead-v">${typeSettings.leading}</b></label>
    <div class="tp-row"><span>Accent</span><div class="accents">${Object.entries(ACCENTS).map(([k, v]) => `<button class="acc ${typeSettings.accent === k ? 'on' : ''}" data-acc="${k}" title="${k}" style="background:${v}"></button>`).join('')}</div></div>
    <div class="tp-section">Window</div>
    <div class="win-row"><span>Colour</span><div class="win-swatches">${WINDOW_COLORS.map(c => `<button class="win-swatch ${typeSettings.bg === c ? 'on' : ''}" data-bg="${c}" style="background:${c}" title="${c}"></button>`).join('')}<input class="win-custom" type="color" id="tp-bg" value="${typeSettings.bg}" title="Any colour"></div></div>
    <label class="tp-row"><span>Opacity</span><input type="range" min="0" max="1" step="0.01" id="tp-alpha" value="${typeSettings.bgAlpha}"><b id="tp-alpha-v">${Math.round(typeSettings.bgAlpha * 100)}%</b></label>
    ${window.renoteNative ? `<label class="tp-row"><span>Blur</span><input type="range" min="0" max="60" step="1" id="tp-blur" value="${typeSettings.blur}"><b id="tp-blur-v">${typeSettings.blur}</b></label>` : '<div class="tp-note">Opacity shows your desktop through the window in the Mac app.</div>'}`;
  document.body.appendChild(panel);
  panel.addEventListener('click', e => e.stopPropagation());
  panel.addEventListener('mousedown', e => e.stopPropagation());
  panel.querySelectorAll('[data-tab]').forEach(t => t.onclick = () => {
    panel.querySelectorAll('[data-tab]').forEach(x => x.classList.toggle('on', x === t));
    panel.querySelectorAll('[data-list]').forEach(l => l.hidden = l.dataset.list !== t.dataset.tab);
  });
  panel.querySelectorAll('[data-font]').forEach(b => b.onclick = () => {
    const [which, name] = b.dataset.font.split('|');
    typeSettings[which] = name;
    panel.querySelectorAll(`[data-font^="${which}|"]`).forEach(x => x.classList.toggle('on', x === b));
    saveType();
  });
  const slider = (id, key, fmt) => { const el = panel.querySelector(id); el.oninput = () => { typeSettings[key] = Number(el.value); panel.querySelector(id + '-v').textContent = fmt(el.value); saveType(); }; };
  slider('#tp-size', 'size', v => v + 'px');
  slider('#tp-width', 'width', v => (Number(v) >= 1500 ? 'Full' : v));
  slider('#tp-lead', 'leading', v => v);
  panel.querySelectorAll('[data-acc]').forEach(b => b.onclick = () => {
    typeSettings.accent = b.dataset.acc;
    panel.querySelectorAll('[data-acc]').forEach(x => x.classList.toggle('on', x === b));
    saveType();
  });
  panel.querySelectorAll('[data-bg]').forEach(b => b.onclick = () => {
    typeSettings.bg = b.dataset.bg;
    panel.querySelector('#tp-bg').value = b.dataset.bg;
    panel.querySelectorAll('[data-bg]').forEach(x => x.classList.toggle('on', x === b));
    saveType();
  });
  panel.querySelector('#tp-bg').oninput = e => {
    typeSettings.bg = e.target.value;
    panel.querySelectorAll('[data-bg]').forEach(x => x.classList.toggle('on', x.dataset.bg === e.target.value));
    saveType();
  };
  const alpha = panel.querySelector('#tp-alpha');
  alpha.oninput = () => { typeSettings.bgAlpha = Number(alpha.value); panel.querySelector('#tp-alpha-v').textContent = Math.round(alpha.value * 100) + '%'; saveType(); };
  const blur = panel.querySelector('#tp-blur');
  if (blur) blur.oninput = () => { typeSettings.blur = Number(blur.value); panel.querySelector('#tp-blur-v').textContent = blur.value; saveType(); };
  panel.querySelector('#tp-reset').onclick = () => { typeSettings = { ...DEFAULT_TYPE }; saveType(); panel.remove(); toggleTypePanel(); };
}
document.addEventListener('mousedown', e => { if (!e.target.closest('#type-panel, #type-btn')) $('#type-panel')?.remove(); });

function blocksHtml(blocks) {
  const out = [];
  for (let i = 0; i < blocks.length; i++) {
    const b = blocks[i];
    // Consecutive definitions share one panel, like a list of rows.
    if (b.type === 'definition') {
      const run = [b];
      while (blocks[i + 1]?.type === 'definition') run.push(blocks[++i]);
      out.push(`<div class="panel defs">${run.map(d => `<div class="def"><div class="term">${renderInline(d.term)}</div><div class="meaning">${renderInline(d.meaning)}</div></div>`).join('')}</div>`);
      continue;
    }
    out.push(blockHtml(b));
  }
  return out.join('');
}

function blockHtml(b) {
  switch (b.type) {
    case 'heading': {
      const lvl = Math.min(6, Math.max(3, b.level + 1));
      return `<h${lvl}>${renderInline(b.text)}</h${lvl}>`;
    }
    case 'paragraph':
      return b.text.includes('{{') ? `<p class="has-gap" title="Click to reveal">${renderInline(b.text)}</p>` : `<p>${renderInline(b.text)}</p>`;
    case 'quote': return `<blockquote>${renderInline(b.text).replace(/\n/g, '<br>')}</blockquote>`;
    case 'divider': return '<hr>';
    case 'list': {
      const tag = b.ordered ? 'ol' : 'ul';
      return `<${tag} class="list">${b.items.map((it, n) => {
        const mk = it.checked !== null
          ? `<button class="check ${it.checked ? 'on' : ''}" data-line="${it.line}" aria-label="${it.checked ? 'Untick' : 'Tick'}">${it.checked ? icon('check', 12) : ''}</button>`
          : b.ordered ? `<span class="mk">${n + 1}</span>` : '<span class="mk bullet"></span>';
        return `<li class="${it.checked ? 'done' : ''}" style="margin-left:${it.indent * 22}px">${mk}<span>${renderInline(it.text)}</span></li>`;
      }).join('')}</${tag}>`;
    }
    case 'code':
      return `<div class="panel code"><div class="head"><span>${icon('code', 13)} ${esc(b.lang || 'code')}</span><button data-copy>${icon('copy', 13)} Copy</button></div><pre>${esc(b.text)}</pre></div>`;
    case 'table':
      return `<div class="panel table"><table><thead><tr>${b.header.map(h => `<th>${renderInline(h)}</th>`).join('')}</tr></thead><tbody>${b.rows.map(r => `<tr>${b.header.map((_, c) => `<td>${renderInline(r[c] || '')}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
    case 'callout': {
      const c = CALLOUTS[b.style];
      return `<div class="panel callout" style="--c:${c.color}"><div class="head"><span class="ico">${icon(c.icon, 13)}</span>${renderInline(b.title)}</div><div class="flow">${blocksHtml(b.body)}</div></div>`;
    }
    case 'toggle':
      return `<details class="panel toggle"><summary>${icon('chev', 14)}${renderInline(b.title)}</summary><div class="flow">${blocksHtml(b.body)}</div></details>`;
    case 'flashcard':
      return `<div class="flash" tabindex="0" role="button" aria-label="Flashcard, press to flip"><div class="inner">
        <div class="face front"><div class="k"><span>Question</span>${icon('flip', 13)}</div><div class="t">${renderInline(b.question)}</div></div>
        <div class="face back"><div class="k"><span>Answer</span>${icon('flip', 13)}</div><div class="t">${renderInline(b.answer).replace(/\n/g, '<br>')}</div></div>
      </div></div>`;
    case 'quiz':
      return `<div class="panel quiz"><div class="label-k">${icon('quiz', 13)} Quiz</div><div class="q">${renderInline(b.question)}</div>
        <div class="opts">${b.options.map((o, i) => `<button class="opt" data-correct="${o.correct}"><span class="letter">${String.fromCharCode(65 + i)}</span><span>${renderInline(o.text)}</span></button>`).join('')}</div><div class="msg"></div></div>`;
    case 'image': {
      const src = /^https?:/.test(b.src) ? b.src : '/api/file?path=' + encodeURIComponent((current()?.subject ? current().subject + '/' : '') + b.src);
      return `<figure style="margin:0"><img src="${esc(src)}" alt="${esc(b.alt)}" loading="lazy">${b.alt ? `<figcaption>${esc(b.alt)}</figcaption>` : ''}</figure>`;
    }
    case 'definition':
      return blocksHtml([b]);
  }
  return '';
}

function wireBlocks(root) {
  root.querySelectorAll('.flash').forEach(f => {
    const flip = () => f.classList.toggle('flipped');
    f.onclick = flip;
    f.onkeydown = e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); flip(); } };
    // Size the card to its taller face.
    const faces = [...f.querySelectorAll('.face')];
    const h = Math.max(...faces.map(x => { x.style.position = 'relative'; const v = x.offsetHeight; x.style.position = ''; return v; }));
    f.querySelector('.inner').style.minHeight = h + 'px';
  });
  root.querySelectorAll('.has-gap').forEach(p => p.onclick = () => p.classList.toggle('revealed'));
  root.querySelectorAll('li .gap').forEach(g => g.onclick = () => g.classList.toggle('open'));
  root.querySelectorAll('.quiz').forEach(q => {
    q.querySelectorAll('.opt').forEach(btn => btn.onclick = () => {
      const answered = q.classList.toggle('answered');
      q.querySelectorAll('.opt').forEach(o => {
        o.classList.remove('right', 'wrong', 'dim');
        if (!answered) return;
        if (o.dataset.correct === 'true') o.classList.add('right');
        else if (o === btn) o.classList.add('wrong');
        else o.classList.add('dim');
      });
      q.querySelector('.msg').textContent = !answered ? '' : btn.dataset.correct === 'true' ? 'Nice one.' : 'Not quite. The right answer is marked.';
    });
  });
  root.querySelectorAll('.check').forEach(c => c.onclick = () => toggleChecklist(Number(c.dataset.line)));
  root.querySelectorAll('[data-copy]').forEach(b => b.onclick = () => {
    copyText(b.closest('.code').querySelector('pre').textContent);
    toast('Copied');
  });
}

function toggleChecklist(line) {
  const lines = state.text.split('\n');
  const l = lines[line];
  if (l == null) return;
  lines[line] = l.includes('[ ]') ? l.replace('[ ]', '[x]') : l.replace(/\[[xX]\]/, '[ ]');
  const y = scrollY;
  setText(lines.join('\n'));
  scrollTo(0, y);
}

const TEMPLATES = {
  quiz: '? Question\n- ( ) Wrong answer\n- (x) Right answer\n- ( ) Wrong answer',
  callout: '> [!tip] Remember\n> Write the key point here',
  toggle: '+++ Click to expand\nHidden details\n+++',
  table: '| Column | Column |\n|---|---|\n| Cell | Cell |',
};

document.addEventListener('click', () => document.querySelectorAll('.menu.open').forEach(m => m.classList.remove('open')));

// ---------- Write view ----------
function writeView() {
  return `<section class="write">
    <div class="pane">
      <div class="toolbar">
        <button class="chip small" data-wrap="**" title="Bold (⌘B)">${icon('bold', 13)}Bold</button>
        <button class="chip small" data-wrap="*" title="Italic (⌘I)">${icon('italic', 13)}Italic</button>
        <button class="chip small" data-wrap="==" title="Highlight (⌘⇧H)">${icon('mark', 13)}Highlight</button>
        <button class="chip small" data-wrap="{{|}}" title="Hide as a gap (⌘⇧G)">${icon('eye', 13)}Gap</button>
        <button class="chip small" data-wrap="\`">${icon('code', 13)}Code</button>
        <button class="chip small" data-insert="Q: Question\nA: Answer">${icon('cards', 13)}Flashcard</button>
        <button class="chip small" data-insert="Term :: What it means">${icon('dict', 13)}Definition</button>
        <button class="chip small" data-insert="${esc(TEMPLATES.quiz)}">${icon('quiz', 13)}Quiz</button>
        <button class="chip small" data-insert="${esc(TEMPLATES.callout)}">${icon('bulb', 13)}Callout</button>
        <button class="chip small" data-insert="${esc(TEMPLATES.toggle)}">${icon('toggle', 13)}Toggle</button>
        <button class="chip small" data-insert="${esc(TEMPLATES.table)}">${icon('table', 13)}Table</button>
      </div>
      <textarea class="editor" id="editor" spellcheck="true">${esc(state.text)}</textarea>
    </div>
    <div class="pane">
      <div class="pane-head"><span>Preview</span><span class="save-state ${state.text !== state.saved ? 'dirty' : ''}"><span class="d"></span><span>${state.text !== state.saved ? 'Saving…' : 'Saved'}</span></span></div>
      <div class="preview" id="preview"><div class="flow">${blocksHtml(parse(state.text))}</div></div>
    </div>
  </section>`;
}

function wireWrite() {
  const ed = $('#editor');
  const preview = $('#preview');
  let t;
  const refresh = () => { preview.innerHTML = `<div class="flow">${blocksHtml(parse(ed.value))}</div>`; wireBlocks(preview); };
  wireBlocks(preview);
  ed.oninput = () => { setText(ed.value, { render: false }); clearTimeout(t); t = setTimeout(refresh, 120); };
  const replace = (start, end, text, selStart, selEnd) => {
    ed.focus();
    ed.setSelectionRange(start, end);
    document.execCommand('insertText', false, text); // keeps undo history
    ed.setSelectionRange(selStart ?? start + text.length, selEnd ?? selStart ?? start + text.length);
    ed.dispatchEvent(new Event('input'));
  };
  const wrap = spec => {
    const [open, close = open] = spec.split('|');
    const { selectionStart: s, selectionEnd: e, value } = ed;
    const sel = value.slice(s, e);
    replace(s, e, open + sel + close, s + open.length, s + open.length + sel.length);
  };
  const insert = snippet => {
    const { selectionStart: s, value } = ed;
    const before = value.slice(0, s);
    const pre = !before || before.endsWith('\n\n') ? '' : before.endsWith('\n') ? '\n' : '\n\n';
    replace(s, ed.selectionEnd, pre + snippet + '\n');
  };
  document.querySelectorAll('[data-wrap]').forEach(b => b.onclick = () => wrap(b.dataset.wrap));
  document.querySelectorAll('[data-insert]').forEach(b => b.onclick = () => insert(b.dataset.insert));
  ed.onkeydown = e => {
    const mod = e.metaKey || e.ctrlKey;
    if (mod && e.key.toLowerCase() === 'b') { e.preventDefault(); wrap('**'); }
    else if (mod && e.key.toLowerCase() === 'i') { e.preventDefault(); wrap('*'); }
    else if (mod && e.shiftKey && e.key.toLowerCase() === 'h') { e.preventDefault(); wrap('=='); }
    else if (mod && e.shiftKey && e.key.toLowerCase() === 'g') { e.preventDefault(); wrap('{{|}}'); }
    else if (e.key === 'Tab') { e.preventDefault(); replace(ed.selectionStart, ed.selectionEnd, '  '); }
    else if (e.key === 'Enter' && !e.shiftKey) {
      // Continue lists and checklists.
      const { selectionStart: s, value } = ed;
      const lineStart = value.lastIndexOf('\n', s - 1) + 1;
      const line = value.slice(lineStart, s);
      const m = /^(\s*)([-*+] \[[ xX]\] |[-*+] \([ xX]\) |[-*+] |(\d+)\. |> )/.exec(line);
      if (!m) return;
      e.preventDefault();
      if (line.trim() === m[2].trim()) { replace(lineStart, s, ''); return; }
      let marker = m[2].replace(/\[[xX]\]/, '[ ]').replace(/\([xX]\)/, '( )');
      if (m[3]) marker = `${Number(m[3]) + 1}. `;
      replace(s, ed.selectionEnd, '\n' + m[1] + marker);
    }
  };
  ed.focus();
  ed.setSelectionRange(ed.value.length, ed.value.length);
}

// ---------- Revise ----------
function shuffle(a) { a = [...a]; for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }
let reviseKeys = null;

function startRevise(root, cards, note) {
  if (!cards.length) {
    root.innerHTML = `<div class="done"><h2>Nothing to revise yet</h2><p>Add a flashcard (Q: / A:), a definition (Term :: meaning),<br>a quiz, or hide words with {{gaps}} and they'll show up here.</p><a class="btn btn-white" href="${noteHref(note.path, 'edit')}">Start writing</a></div>`;
    return;
  }
  const s = { deck: shuffle(cards), i: 0, flipped: false, known: new Set(), again: [], round: 1, logged: false };

  const draw = () => {
    if (s.i >= s.deck.length) return finish();
    const c = s.deck[s.i];
    const front = c.kind === 'Fill the gap' ? renderInline(c.front)
      : c.kind === 'Definition' ? `<span class="define">Define</span>${renderInline(c.front)}`
      : c.kind === 'Quiz' ? `${renderInline(c.front)}<div class="opts">${c.options.map((o, k) => `<div><span>${String.fromCharCode(65 + k)}</span>${renderInline(o.text)}</div>`).join('')}</div>`
      : renderInline(c.front);
    const back = c.kind === 'Definition' ? `<span class="define" style="color:rgba(0,0,0,.45)">${renderInline(c.front)}</span>${renderInline(c.back)}` : renderInline(c.back).replace(/\n/g, '<br>');
    root.innerHTML = `<div class="deck">
      <div class="top"><b>${esc(note.title)}</b><span>${s.round > 1 ? `Round ${s.round} · ` : ''}${s.i + 1} of ${s.deck.length}</span></div>
      <div class="progress"><div style="width:${(s.i / s.deck.length) * 100}%"></div></div>
      <div class="card ${s.flipped ? 'flipped' : ''}" id="card"><div class="inner">
        <div class="face front"><div class="kind">${c.kind}</div><div class="body">${front}</div></div>
        <div class="face back"><div class="kind">Answer</div><div class="body">${back}</div></div>
      </div></div>
      <div class="actions" id="deck-actions"></div>
      <div class="keys" id="deck-keys"></div>
    </div>`;
    $('#card').onclick = flip;
    drawActions();
  };
  // Only the buttons change on a flip, so the card itself can animate.
  const drawActions = () => {
    $('#deck-actions').innerHTML = s.flipped
      ? `<button class="btn btn-grey" id="again">${icon('undo', 14)} Again</button><button class="btn btn-white" id="got">${icon('check', 14)} Got it</button>`
      : `<button class="btn btn-white" id="flip">${icon('flip', 14)} Show answer</button>`;
    $('#deck-keys').textContent = s.flipped ? '← again · → got it' : 'space to flip';
    $('#flip') && ($('#flip').onclick = flip);
    $('#again') && ($('#again').onclick = () => answer(false));
    $('#got') && ($('#got').onclick = () => answer(true));
  };
  const flip = () => {
    s.flipped = !s.flipped;
    $('#card').classList.toggle('flipped', s.flipped);
    drawActions();
  };
  const answer = knew => {
    const c = s.deck[s.i];
    if (knew) s.known.add(c.id); else s.again.push(c);
    s.i++; s.flipped = false;
    draw();
  };
  const finish = async () => {
    const pct = Math.round((s.known.size / cards.length) * 100);
    if (!s.logged) {
      s.logged = true;
      // Logged once per full pass so Progress can show history and what's due.
      api.send('POST', '/api/log', { path: note.path, title: note.title, subject: note.subject, cards: cards.length, known: s.known.size, rounds: s.round })
        .then(async () => { state.log = await api.get('/api/log'); renderAnnounce(); }).catch(() => {});
    }
    root.innerHTML = `<div class="done">
      <div class="ring-wrap"><div class="ring" style="--p:${pct}"></div><div class="pct">${pct}%</div></div>
      <h2>${pct === 100 ? 'All done. You know this note.' : 'Round complete'}</h2>
      <p>${s.known.size} of ${cards.length} cards known${s.again.length ? ` · ${s.again.length} to go again` : ''}</p>
      <div class="actions" style="display:flex;gap:10px;justify-content:center">
        ${s.again.length ? `<button class="btn btn-white" id="retry">Revise the ${s.again.length} missed</button>` : ''}
        <button class="btn btn-grey" id="restart">Start over</button>
        <a class="btn btn-ghost" href="#/progress">See progress</a>
      </div></div>`;
    $('#retry') && ($('#retry').onclick = () => { s.deck = shuffle(s.again); s.again = []; s.i = 0; s.round++; draw(); });
    $('#restart').onclick = () => startRevise(root, cards, note);
  };
  reviseKeys = e => {
    if (!document.body.contains(root) || e.target.closest('input, textarea')) return;
    if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); if (s.i < s.deck.length) flip(); }
    else if (e.key === 'ArrowRight' && s.flipped) answer(true);
    else if (e.key === 'ArrowLeft' && s.flipped) answer(false);
  };
  draw();
}
document.addEventListener('keydown', e => reviseKeys && reviseKeys(e));

function renderReviseHub(main) {
  const rows = state.notes.map(n => ({ n, last: state.log.filter(e => e.path === n.path).at(-1) }));
  main.innerHTML = `
    <section class="hero"><div class="eyebrow"><span>Revise</span></div>
      <h2 class="big reveal">Pick a note and test yourself</h2>
      <p class="lede">Every flashcard, definition, quiz and gap in a note becomes a card. Space flips, arrows mark it.</p></section>
    <div class="chart-wrap"><div class="panel log">${rows.map(({ n, last }) => `
      <a href="${noteHref(n.path, 'revise')}"><span style="color:var(--text)">${esc(n.title)}</span>
      <span class="when">${last ? 'Last ' + timeAgo(Date.parse(last.at)) : 'Never revised'}</span>
      <span class="score">${last ? Math.round((last.known / last.cards) * 100) + '%' : '·'}</span>${icon('chev', 14)}</a>`).join('') || '<div class="empty">No notes yet.</div>'}</div></div>`;
}

// ---------- Progress ----------
function renderProgress(main) {
  const log = state.log;
  const reviewed = log.reduce((t, e) => t + e.cards, 0);
  const known = log.reduce((t, e) => t + e.known, 0);
  const days = new Set(log.map(e => e.at.slice(0, 10)));
  let streak = 0;
  for (let d = new Date(); days.has(d.toISOString().slice(0, 10)); d.setDate(d.getDate() - 1)) streak++;
  const latest = {};
  for (const e of log) latest[e.path] = e;
  const mastery = Object.values(latest).map(e => ({ title: e.title, path: e.path, pct: Math.round((e.known / e.cards) * 100) })).sort((a, b) => b.pct - a.pct);
  main.innerHTML = `
    <section class="hero"><div class="eyebrow"><span>Progress</span><span class="dot"></span><span>Logged in .renote/log.json</span></div>
      <h2 class="big reveal">Your revision, at a glance</h2>
      <p class="lede">Every finished Revise session is logged, so you can see what's sticking and what needs another go.</p></section>
    <div class="stats">
      <div class="stat"><div class="v">${log.length}</div><div class="l">Sessions</div></div>
      <div class="stat"><div class="v">${reviewed}</div><div class="l">Cards reviewed</div></div>
      <div class="stat"><div class="v">${reviewed ? Math.round((known / reviewed) * 100) : 0}%</div><div class="l">Known first time</div></div>
      <div class="stat"><div class="v">${streak}</div><div class="l">Day streak</div></div>
    </div>
    <div class="chart-wrap"><div class="panel chart"><h3>Mastery by note</h3><div class="s">Your latest score on each note</div>
      <div class="bars">${mastery.map(m => `<a class="barrow" href="${noteHref(m.path, 'revise')}"><span>${esc(m.title)}</span><div class="track"><div class="fill" style="width:${m.pct}%"></div></div><span class="n">${m.pct}%</span></a>`).join('') || '<div style="color:var(--faint);font-size:14px">Finish a Revise session to see it here.</div>'}</div>
    </div></div>
    <div class="chart-wrap"><div class="panel log">${[...log].reverse().slice(0, 30).map(e => `
      <a href="${noteHref(e.path, 'revise')}"><span style="color:var(--text)">${esc(e.title)}</span><span class="when">${new Date(e.at).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' })}</span><span class="score">${e.known}/${e.cards}</span>${icon('chev', 14)}</a>`).join('') || '<div class="empty">No sessions yet.</div>'}</div></div>`;
}

// ---------- Reveal on scroll ----------
const io = new IntersectionObserver(entries => entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { threshold: 0.2 });
function observeReveals() {
  document.querySelectorAll('.reveal:not(.in)').forEach(el => {
    io.observe(el);
    // Anything already on screen sharpens straight away, even if observers are throttled.
    setTimeout(() => { if (el.getBoundingClientRect().top < innerHeight) el.classList.add('in'); }, 60);
  });
}

// ---------- Background specks ----------
function specks() {
  const c = $('#specks');
  const dpr = devicePixelRatio || 1;
  c.width = innerWidth * dpr; c.height = innerHeight * dpr;
  const ctx = c.getContext('2d');
  let seed = 7;
  const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < 90; i++) {
    ctx.fillStyle = `rgba(255,255,255,${0.06 + rnd() * 0.2})`;
    const r = (0.4 + rnd() * 0.8) * dpr;
    ctx.beginPath(); ctx.arc(rnd() * c.width, rnd() * c.height, r, 0, 7); ctx.fill();
  }
}

// ---------- Global wiring ----------
$('#new-note').onclick = () => {
  const subject = parseHash().subject;
  newNote(subject && subject !== '~' ? subject : current()?.subject || null);
};
$('#search').oninput = e => {
  state.search = e.target.value;
  if (parseHash().view !== 'home') location.hash = '#/';
  else { renderHome($('#main'), parseHash().subject); observeReveals(); }
};
document.addEventListener('keydown', e => {
  const mod = e.metaKey || e.ctrlKey;
  if (mod && !e.shiftKey && e.key.toLowerCase() === 'e') { e.preventDefault(); toggleEdit(); return; }
  if (mod && e.key === '\\') { e.preventDefault(); toggleFocus(); return; }
  if (e.target.closest('input, textarea') || e.metaKey || e.ctrlKey || e.altKey) {
    if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); saveNow().then(() => toast('Saved')); }
    return;
  }
  const r = parseHash();
  if (e.key === '/') { e.preventDefault(); $('#search').focus(); }
  else if (e.key === 'n') newNote(current()?.subject || null);
  else if (r.view === 'note' && ['1', '2', '3'].includes(e.key)) location.hash = noteHref(r.path, ['read', 'edit', 'revise'][e.key - 1]);
});
addEventListener('beforeunload', e => { pageEditor?.flush(); if (state.text !== state.saved) { saveNow(); e.preventDefault(); } });
let lastRoute = parseHash();
addEventListener('hashchange', async () => {
  reviseKeys = null;
  const r = parseHash();
  const sameNote = r.view === 'note' && lastRoute.view === 'note' && r.path === lastRoute.path && ['read', 'edit'].includes(r.mode) && ['read', 'edit'].includes(lastRoute.mode);
  const y = scrollY;
  lastRoute = r;
  if (sameNote && pageEditor) {
    // Same page, just switch between reading and typing.
    const editing = r.mode === 'edit';
    pageEditor.setEditable(editing);
    $('#page-wrap')?.classList.toggle('editing', editing);
    const note = current();
    $('#dock')?.remove();
    $('#main').insertAdjacentHTML('beforeend', dockHtml(note, r.mode, studyCards(parse(state.text)).length));
    wireDock(note, r.mode);
    const flip = JSON.parse(sessionStorage.getItem('renote-flip') || '{}');
    sessionStorage.removeItem('renote-flip');
    if (editing) {
      if (flip.pos != null) pageEditor.editor.chain().focus().setTextSelection(flip.pos).run();
      else pageEditor.editor.commands.focus(null, { scrollIntoView: false });
    } else {
      pageEditor.flush();
      saveNow();
    }
    renderSidebar(r);
    return;
  }
  sessionStorage.removeItem('renote-flip');
  if (pageEditor) pageEditor.flush();
  await route();
  scrollTo(0, sameNote ? y : 0);
});
addEventListener('resize', specks);

// ---------- Mac app bridge ----------
const native = window.webkit?.messageHandlers?.renote;
function copyText(text) {
  if (native) native.postMessage({ copy: text });
  else navigator.clipboard?.writeText(text);
}
// Tell the Mac app which parts of the top bar are controls, so the rest drags the window.
function reportNoDrag() {
  if (!native) return;
  const nav = $('.nav');
  const rects = [...nav.querySelectorAll('a, button, input, label')].map(el => {
    const r = el.getBoundingClientRect();
    return { x: r.left, y: r.top, w: r.width, h: r.height };
  });
  // The Mac app puts an extra-frosted layer behind the sidebar, so tell it how wide it is.
  const side = $('#sidebar');
  const sideWidth = side && getComputedStyle(side).display !== 'none' && !document.body.classList.contains('focus') ? side.getBoundingClientRect().width : 0;
  native.postMessage({ noDrag: rects, bar: nav.getBoundingClientRect().height, sidebar: sideWidth });
}
async function newSubjectPrompt() {
  const name = prompt('Name the new subject', 'New Subject');
  if (!name) return;
  const { name: made } = await api.send('POST', '/api/subject', { name });
  await loadIndex();
  location.hash = '#/subject/' + encodeURIComponent(made);
}
window.renote = {
  newNote: () => newNote(current()?.subject || null),
  newSubject: newSubjectPrompt,
  focusSearch: () => $('#search').focus(),
  go: hash => { location.hash = hash; },
  setMode: mode => { const r = parseHash(); if (r.view === 'note') location.hash = noteHref(r.path, mode === 'write' ? 'edit' : mode); },
  toggleEdit: () => toggleEdit(),
  toggleSidebar: toggleFocus,
  showType: toggleTypePanel,
};
addEventListener('resize', reportNoDrag);

specks();
try { if (localStorage.getItem('renote-focus')) document.body.classList.add('focus'); } catch {}
applyType();
api.get('/api/settings').then(s => { if (s?.type) { typeSettings = { ...DEFAULT_TYPE, ...s.type }; applyType(); } }).catch(() => {});
await loadIndex();
route();
reportNoDrag();
setTimeout(reportNoDrag, 500); // after web fonts settle
