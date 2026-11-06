// Renote's local server. No dependencies: it serves the site in ./public and keeps
// your notes as plain Markdown files in ~/Documents/Renote (or RENOTE_DIR).
// Sub-folders are subjects. Revision sessions are logged to .renote/log.json.
import { createServer } from 'node:http';
import { readFile, writeFile, readdir, stat, mkdir, rename, access } from 'node:fs/promises';
import { join, resolve, extname, relative, sep, dirname, basename } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(process.env.RENOTE_DIR || join(homedir(), 'Documents', 'Renote'));
const PUBLIC = join(dirname(fileURLToPath(import.meta.url)), 'public');
const PORT = Number(process.env.PORT || 4321);
const LOG = join(ROOT, '.renote', 'log.json');
const NOTE_EXT = new Set(['.md', '.markdown', '.txt']);
const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp' };

const exists = p => access(p).then(() => true, () => false);

/** Resolves a path inside the notes folder, refusing anything that escapes it. */
function safe(rel = '') {
  const full = resolve(ROOT, rel);
  if (full !== ROOT && !full.startsWith(ROOT + sep)) throw Object.assign(new Error('Path outside notes folder'), { status: 400 });
  return full;
}

function titleOf(body, file) {
  const line = body.split('\n').find(l => l.trim().startsWith('# '));
  return line ? line.trim().slice(2).replace(/[*_=~`{}^+]/g, '').trim() : basename(file, extname(file));
}

async function readNote(full, subject) {
  const [body, info] = await Promise.all([readFile(full, 'utf8'), stat(full)]);
  const preview = body.split('\n').map(l => l.trim()).filter(l => l && !l.startsWith('#') && !l.startsWith('```')).slice(0, 2).join(' ').replace(/[*_=~`{}^>|]/g, '').slice(0, 160);
  return { path: relative(ROOT, full).split(sep).join('/'), title: titleOf(body, full), preview, subject, modified: info.mtimeMs };
}

async function listNotes() {
  const notes = [];
  const subjects = [];
  for (const entry of await readdir(ROOT, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue;
    const full = join(ROOT, entry.name);
    if (entry.isDirectory()) {
      subjects.push(entry.name);
      for (const inner of await readdir(full, { withFileTypes: true })) {
        if (inner.isFile() && NOTE_EXT.has(extname(inner.name).toLowerCase()) && !inner.name.startsWith('.')) notes.push(await readNote(join(full, inner.name), entry.name));
      }
    } else if (NOTE_EXT.has(extname(entry.name).toLowerCase())) {
      notes.push(await readNote(full, null));
    }
  }
  subjects.sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
  notes.sort((a, b) => b.modified - a.modified);
  return { folder: ROOT, subjects, notes };
}

async function uniqueName(dir, base, ext = '.md') {
  let name = base, n = 2;
  while (await exists(join(dir, name + ext))) name = `${base} ${n++}`;
  return name;
}

async function readLog() {
  try { return JSON.parse(await readFile(LOG, 'utf8')); } catch { return []; }
}

async function body(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const text = Buffer.concat(chunks).toString('utf8');
  return text ? JSON.parse(text) : {};
}

function send(res, status, data) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(data));
}

async function api(req, res, url) {
  const route = `${req.method} ${url.pathname}`;
  switch (route) {
    case 'GET /api/notes':
      return send(res, 200, await listNotes());
    case 'GET /api/note': {
      const full = safe(url.searchParams.get('path'));
      return send(res, 200, { path: url.searchParams.get('path'), text: await readFile(full, 'utf8') });
    }
    case 'PUT /api/note': {
      const { path, text } = await body(req);
      await writeFile(safe(path), text, 'utf8');
      return send(res, 200, await readNote(safe(path), path.includes('/') ? path.split('/')[0] : null));
    }
    case 'POST /api/note': {
      const { subject } = await body(req);
      const dir = safe(subject || '');
      await mkdir(dir, { recursive: true });
      const name = await uniqueName(dir, 'Untitled');
      const full = join(dir, name + '.md');
      await writeFile(full, `# ${name}\n\n`, 'utf8');
      return send(res, 201, await readNote(full, subject || null));
    }
    case 'POST /api/note/rename': {
      const { path, name } = await body(req);
      const clean = String(name).replace(/[\/\\]/g, '-').trim();
      if (!clean) return send(res, 400, { error: 'Name required' });
      const from = safe(path);
      const to = join(dirname(from), clean + extname(from));
      if (await exists(to)) return send(res, 409, { error: 'A note with that name already exists' });
      await rename(from, to);
      return send(res, 200, { path: relative(ROOT, to).split(sep).join('/') });
    }
    case 'POST /api/note/trash': {
      // Moved into .renote/trash rather than deleted, so nothing is lost.
      const { path } = await body(req);
      const trash = join(ROOT, '.renote', 'trash');
      await mkdir(trash, { recursive: true });
      await rename(safe(path), join(trash, `${Date.now()}-${basename(path)}`));
      return send(res, 200, { ok: true });
    }
    case 'POST /api/subject': {
      const { name } = await body(req);
      const clean = String(name || 'New Subject').replace(/[\/\\.]/g, '-').trim() || 'New Subject';
      let final = clean, n = 2;
      while (await exists(safe(final))) final = `${clean} ${n++}`;
      await mkdir(safe(final));
      return send(res, 201, { name: final });
    }
    case 'GET /api/log':
      return send(res, 200, await readLog());
    case 'POST /api/log': {
      const entry = await body(req);
      const log = await readLog();
      log.push({ ...entry, at: new Date().toISOString() });
      await mkdir(dirname(LOG), { recursive: true });
      await writeFile(LOG, JSON.stringify(log, null, 2), 'utf8');
      return send(res, 201, { ok: true, count: log.length });
    }
    case 'GET /api/file': {
      // Images referenced from notes, e.g. ![](diagram.png)
      const full = safe(url.searchParams.get('path'));
      res.writeHead(200, { 'content-type': TYPES[extname(full).toLowerCase()] || 'application/octet-stream' });
      return res.end(await readFile(full));
    }
  }
  send(res, 404, { error: 'Not found' });
}

async function seed() {
  if (await exists(ROOT)) return;
  await mkdir(join(ROOT, 'Biology'), { recursive: true });
  const samples = join(dirname(fileURLToPath(import.meta.url)), 'samples');
  await writeFile(join(ROOT, 'Welcome to Renote.md'), await readFile(join(samples, 'welcome.md'), 'utf8'));
  await writeFile(join(ROOT, 'Biology', 'Cell Biology.md'), await readFile(join(samples, 'cell-biology.md'), 'utf8'));
}

await seed();

createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  try {
    if (url.pathname.startsWith('/api/')) return await api(req, res, url);
    const file = resolve(PUBLIC, '.' + (url.pathname === '/' ? '/index.html' : decodeURIComponent(url.pathname)));
    if (!file.startsWith(PUBLIC + sep)) return send(res, 400, { error: 'Bad path' });
    const data = await readFile(file).catch(() => readFile(join(PUBLIC, 'index.html')));
    res.writeHead(200, { 'content-type': TYPES[extname(file)] || 'text/html; charset=utf-8', 'cache-control': 'no-store' });
    res.end(data);
  } catch (err) {
    console.error(err);
    send(res, err.status || (err.code === 'ENOENT' ? 404 : 500), { error: err.message });
  }
}).listen(PORT, '127.0.0.1', () => {
  console.log(`Renote is running at http://localhost:${PORT}`);
  console.log(`Notes folder: ${ROOT}`);
});
