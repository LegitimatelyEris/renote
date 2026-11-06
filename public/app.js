import { parse, renderInline, plain, studyCards, CALLOUTS } from './markdown.js';

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
    <div class="workspace"><span class="tile">R</span>Renote<span class="count">${state.notes.length} notes</span></div>
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
  location.hash = noteHref(note.path, 'write');
}

// ---------- Note view ----------
function splitSections(blocks) {
  const out = { title: null, lede: null, intro: [], sections: [] };
  let i = 0;
  if (blocks[0]?.type === 'heading' && blocks[0].level === 1) { out.title = blocks[0].text; i = 1; }
  if (blocks[i]?.type === 'paragraph' && !blocks[i].text.includes('{{')) { out.lede = blocks[i].text; i++; }
  let cur = null;
  for (; i < blocks.length; i++) {
    const b = blocks[i];
    if (b.type === 'heading' && b.level <= 2) { cur = { heading: b, blocks: [] }; out.sections.push(cur); }
    else (cur ? cur.blocks : out.intro).push(b);
  }
  return out;
}

function renderNote(main, mode) {
  const note = current();
  if (!note) { location.hash = '#/'; return; }
  const blocks = parse(state.text);
  const cards = studyCards(blocks);
  const words = state.text.split(/\s+/).filter(Boolean).length;
  const { title, lede, intro, sections } = splitSections(blocks);
  const modeChip = (m, ic, label) => `<a class="chip ${mode === m ? 'on' : ''}" href="${noteHref(note.path, m)}">${icon(ic, 14)}${label}</a>`;
  const hero = `
    <section class="hero ${mode === 'read' ? '' : 'compact'}">
      <div class="eyebrow">
        ${note.subject ? `<a href="#/subject/${encodeURIComponent(note.subject)}" style="color:inherit">${esc(note.subject)}</a><span class="dot"></span>` : ''}
        <span>${Math.max(1, Math.round(words / 200))} min read</span><span class="dot"></span>
        <span>Edited ${timeAgo(note.modified)}</span>
        ${cards.length ? `<span class="dot"></span><a href="${noteHref(note.path, 'revise')}">${cards.length} to revise</a>` : ''}
      </div>
      <h1 class="reveal">${renderInline(title || note.title)}</h1>
      ${lede && mode === 'read' ? `<p class="lede">${renderInline(lede)}</p>` : ''}
      <div class="bar">
        <div class="chips">${modeChip('read', 'book', 'Read')}${modeChip('write', 'pen', 'Write')}${modeChip('revise', 'cards', `Revise${cards.length ? ' · ' + cards.length : ''}`)}</div>
        <div class="right">
          <button class="icon-btn" id="rename" title="Rename">${icon('edit')}</button>
          <button class="icon-btn" id="trash" title="Move to trash">${icon('trash')}</button>
        </div>
      </div>
    </section>`;

  if (mode === 'write') main.innerHTML = hero + writeView();
  else if (mode === 'revise') main.innerHTML = hero + `<section class="revise" id="revise"></section>`;
  else main.innerHTML = hero + readView(intro, sections) + composerView();

  $('#rename').onclick = async () => {
    const name = prompt('Rename note', note.path.split('/').pop().replace(/\.\w+$/, ''));
    if (!name) return;
    await saveNow();
    try {
      const { path } = await api.send('POST', '/api/note/rename', { path: note.path, name });
      await loadIndex();
      state.path = path;
      location.hash = noteHref(path, mode);
    } catch (e) { toast(e.message); }
  };
  $('#trash').onclick = async () => {
    if (!confirm(`Move “${note.title}” to the trash? It is kept in .renote/trash inside your notes folder.`)) return;
    await saveNow();
    await api.send('POST', '/api/note/trash', { path: note.path });
    state.path = null;
    await loadIndex();
    location.hash = '#/';
    toast('Moved to trash');
  };

  if (mode === 'write') wireWrite();
  else if (mode === 'revise') startRevise($('#revise'), cards, note);
  else { wireBlocks(main); wireComposer(); }
}

function readView(intro, sections) {
  const introHtml = intro.length ? `<section class="intro"><div class="flow">${blocksHtml(intro)}</div></section>` : '';
  let n = 0;
  const secs = sections.map(s => {
    n++;
    const sc = studyCards(s.blocks).length;
    return `<section class="section">
      <div class="label"><div class="sticky reveal">
        <div class="num">${String(n).padStart(2, '0')}</div>
        <h2>${renderInline(s.heading.text)}</h2>
        ${sc ? `<div class="sub">${sc} ${sc === 1 ? 'card' : 'cards'} to revise</div>` : ''}
      </div></div>
      <div class="content"><div class="flow">${blocksHtml(s.blocks) || '<p style="color:var(--faint)">Nothing here yet.</p>'}</div></div>
    </section>`;
  }).join('');
  return introHtml + secs;
}

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

// ---------- Composer ----------
const KINDS = {
  text: { label: 'Text', icon: 'lines', a: 'Add to this note… (Markdown works)' },
  flashcard: { label: 'Flashcard', icon: 'cards', a: 'Question', b: 'Answer' },
  definition: { label: 'Definition', icon: 'dict', a: 'Term', b: 'What it means' },
  todo: { label: 'To-do', icon: 'todo', a: 'Something to do' },
  gap: { label: 'Gap fill', icon: 'eye', a: 'Sentence with the {{hidden part}} in double braces' },
  heading: { label: 'Section', icon: 'lines', a: 'Section heading' },
};
let composerKind = 'text';

function composerView() {
  const k = KINDS[composerKind];
  return `<section class="composer"><div class="box">
    <textarea id="c-a" rows="1" placeholder="${esc(k.a)}"></textarea>
    ${k.b ? `<div class="second"><textarea id="c-b" rows="1" placeholder="${esc(k.b)}"></textarea></div>` : ''}
    <div class="row">
      <div class="menu" id="c-menu"><button class="icon-btn" id="c-plus" title="Insert a component">${icon('plus')}</button>
        <div class="list-menu">
          <button data-tpl="quiz">${icon('quiz')} Quiz</button>
          <button data-tpl="callout">${icon('bulb')} Callout</button>
          <button data-tpl="toggle">${icon('toggle')} Toggle</button>
          <button data-tpl="table">${icon('table')} Table</button>
          <button data-tpl="code">${icon('code')} Code block</button>
          <button data-tpl="divider">${icon('lines')} Divider</button>
        </div></div>
      <div class="chips">${Object.entries(KINDS).map(([key, v]) => `<button class="chip small ${key === composerKind ? 'on' : ''}" data-kind="${key}">${icon(v.icon, 13)}${v.label}</button>`).join('')}</div>
      <button class="send" id="c-send" disabled title="Add to note (Enter)">${icon('up', 15)}</button>
    </div></div>
    <div class="hint">Enter adds it to the end of this note · Shift+Enter for a new line</div>
  </section>`;
}

const TEMPLATES = {
  quiz: '? Question\n- ( ) Wrong answer\n- (x) Right answer\n- ( ) Wrong answer',
  callout: '> [!tip] Remember\n> Write the key point here',
  toggle: '+++ Click to expand\nHidden details\n+++',
  table: '| Column | Column |\n|---|---|\n| Cell | Cell |',
  code: '```\ncode\n```',
  divider: '---',
};

function appendSnippet(snippet) {
  let base = state.text.replace(/\n+$/, '');
  setText((base ? base + '\n\n' : '') + snippet + '\n');
  requestAnimationFrame(() => scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' }));
}

function wireComposer() {
  const a = $('#c-a'), b = $('#c-b'), send = $('#c-send');
  const grow = t => { t.style.height = 'auto'; t.style.height = t.scrollHeight + 'px'; };
  const valid = () => a.value.trim() && (!b || b.value.trim());
  const update = () => { send.disabled = !valid(); };
  const submit = () => {
    if (!valid()) return;
    const x = a.value.trim(), y = b?.value.trim();
    const snippet = { text: x, flashcard: `Q: ${x}\nA: ${y}`, definition: `${x} :: ${y}`, todo: `- [ ] ${x}`, gap: x.includes('{{') ? x : `{{${x}}}`, heading: `## ${x}` }[composerKind];
    sessionStorage.setItem('renote-focus-composer', '1');
    appendSnippet(snippet);
  };
  [a, b].filter(Boolean).forEach(t => {
    t.oninput = () => { grow(t); update(); };
    t.onkeydown = e => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        if (t === a && b && !b.value.trim()) b.focus(); else submit();
      }
    };
  });
  send.onclick = submit;
  document.querySelectorAll('[data-kind]').forEach(c => c.onclick = () => {
    composerKind = c.dataset.kind;
    sessionStorage.setItem('renote-focus-composer', '1');
    route();
  });
  const menu = $('#c-menu');
  $('#c-plus').onclick = e => { e.stopPropagation(); menu.classList.toggle('open'); };
  menu.querySelectorAll('[data-tpl]').forEach(btn => btn.onclick = () => { menu.classList.remove('open'); appendSnippet(TEMPLATES[btn.dataset.tpl]); });
  if (sessionStorage.getItem('renote-focus-composer')) {
    sessionStorage.removeItem('renote-focus-composer');
    a.focus({ preventScroll: true });
  }
}
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
    root.innerHTML = `<div class="done"><h2>Nothing to revise yet</h2><p>Add a flashcard (Q: / A:), a definition (Term :: meaning),<br>a quiz, or hide words with {{gaps}} and they'll show up here.</p><a class="btn btn-white" href="${noteHref(note.path, 'write')}">Start writing</a></div>`;
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
  if (e.target.closest('input, textarea') || e.metaKey || e.ctrlKey || e.altKey) {
    if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); saveNow().then(() => toast('Saved')); }
    return;
  }
  const r = parseHash();
  if (e.key === '/') { e.preventDefault(); $('#search').focus(); }
  else if (e.key === 'n') newNote(current()?.subject || null);
  else if (r.view === 'note' && ['1', '2', '3'].includes(e.key)) location.hash = noteHref(r.path, ['read', 'write', 'revise'][e.key - 1]);
});
addEventListener('beforeunload', e => { if (state.text !== state.saved) { saveNow(); e.preventDefault(); } });
addEventListener('hashchange', () => { reviseKeys = null; route(); scrollTo(0, 0); });
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
  native.postMessage({ noDrag: rects, bar: nav.getBoundingClientRect().height });
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
  setMode: mode => { const r = parseHash(); if (r.view === 'note') location.hash = noteHref(r.path, mode); },
};
addEventListener('resize', reportNoDrag);

specks();
await loadIndex();
route();
reportNoDrag();
setTimeout(reportNoDrag, 500); // after web fonts settle
