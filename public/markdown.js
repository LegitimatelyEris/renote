// Renote's Markdown: generic Markdown plus revision components.
// parse(text) -> blocks, renderInline(text) -> HTML, studyCards(blocks) -> cards.

const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export const CALLOUTS = {
  note: { label: 'Note', icon: 'pencil', color: '#a1a1aa' },
  tip: { label: 'Tip', icon: 'bulb', color: '#4ade80' },
  info: { label: 'Info', icon: 'info', color: '#60a5fa' },
  important: { label: 'Important', icon: 'alert', color: '#c084fc' },
  warning: { label: 'Warning', icon: 'triangle', color: '#fb923c' },
  danger: { label: 'Danger', icon: 'flame', color: '#f87171' },
  example: { label: 'Example', icon: 'list', color: '#2dd4bf' },
  question: { label: 'Question', icon: 'help', color: '#818cf8' },
  summary: { label: 'Summary', icon: 'lines', color: '#5eead4' },
  remember: { label: 'Remember', icon: 'brain', color: '#f472b6' },
};
const CALLOUT_ALIASES = { hint: 'tip', caution: 'warning', attention: 'warning', error: 'danger', bug: 'danger', fail: 'danger', faq: 'question', help: 'question', tldr: 'summary', abstract: 'summary', memo: 'remember', key: 'remember', keypoint: 'remember' };
export const calloutStyle = raw => { const k = raw.toLowerCase(); return CALLOUTS[k] ? k : CALLOUT_ALIASES[k] || 'note'; };

const COLORS = { red: '#f87171', orange: '#fb923c', yellow: '#facc15', green: '#4ade80', mint: '#6ee7b7', teal: '#2dd4bf', blue: '#60a5fa', indigo: '#818cf8', purple: '#c084fc', pink: '#f472b6', brown: '#c8a27a', gray: '#a1a1aa', grey: '#a1a1aa' };

// ---------- Blocks ----------

const heading = l => { const m = /^(#{1,6}) (.*)$/.exec(l); return m ? [m[1].length, m[2].trim()] : null; };
const isDivider = l => { const c = l.replace(/ /g, ''); return c.length >= 3 && /^([-*_])\1+$/.test(c); };
const quizOption = raw => { const m = /^\s*[-*] \(([ xX])\)\s*(.*)$/.exec(raw); return m ? { text: m[2], correct: m[1] !== ' ' } : null; };
const isTableSep = raw => { const l = raw.trim(); return l.startsWith('|') && l.includes('-') && /^[|\-: ]+$/.test(l); };
const cells = line => { let l = line.trim(); if (l.startsWith('|')) l = l.slice(1); if (l.endsWith('|')) l = l.slice(0, -1); return l.split('|').map(c => c.trim()); };

function listMarker(raw) {
  if (quizOption(raw)) return null;
  const m = /^([ \t]*)(?:([-*+])|(\d+)[.)]) (.*)$/.exec(raw);
  if (!m) return null;
  const indent = Math.floor(m[1].replace(/\t/g, '    ').length / 2);
  let text = m[4], checked = null;
  if (text.startsWith('[ ] ')) { checked = false; text = text.slice(4); }
  else if (/^\[[xX]\] /.test(text)) { checked = true; text = text.slice(4); }
  return { indent, ordered: !m[2], checked, text };
}

export function parse(text) {
  let id = 0;
  const lines = text.replace(/\r\n/g, '\n').split('\n').map((l, i) => [i, l]);
  const make = (type, props) => ({ id: id++, type, ...props });

  // Every block records the source lines it came from (start..end, inclusive),
  // so the page editor can swap exactly those lines.
  function run(lines) {
    const blocks = [];
    let para = [], paraStart = 0, paraEnd = 0;
    const flush = () => {
      if (para.length) { blocks.push(make('paragraph', { text: para.join(' '), start: paraStart, end: paraEnd })); para = []; }
    };
    const push = (block, from, to) => { block.start = lines[from][0]; block.end = lines[Math.max(from, to - 1)][0]; blocks.push(block); };
    let i = 0;
    while (i < lines.length) {
      const i0 = i;
      const [lineNo, raw] = lines[i];
      const line = raw.trim();
      if (!line) { flush(); i++; continue; }

      if (line.startsWith('```')) {
        flush();
        const lang = line.slice(3).trim();
        const body = [];
        i++;
        while (i < lines.length && !lines[i][1].trim().startsWith('```')) body.push(lines[i++][1]);
        i = Math.min(i + 1, lines.length);
        push(make('code', { lang, text: body.join('\n') }), i0, i);
        continue;
      }
      if (line.startsWith('+++')) {
        flush();
        const title = line.slice(3).trim() || 'Details';
        const body = [];
        i++;
        while (i < lines.length && lines[i][1].trim() !== '+++') body.push(lines[i++]);
        i = Math.min(i + 1, lines.length);
        push(make('toggle', { title, body: run(body) }), i0, i);
        continue;
      }
      const h = heading(line);
      if (h) { flush(); i++; push(make('heading', { level: h[0], text: h[1], line: lineNo }), i0, i); continue; }
      if (isDivider(line)) { flush(); i++; push(make('divider'), i0, i); continue; }

      if (line.startsWith('>')) {
        flush();
        const quoted = [];
        while (i < lines.length && lines[i][1].trim().startsWith('>')) {
          let s = lines[i][1].trim().slice(1);
          if (s.startsWith(' ')) s = s.slice(1);
          quoted.push([lines[i][0], s]);
          i++;
        }
        const m = /^\[!(\w+)\][+-]?\s*(.*)$/.exec(quoted[0][1]);
        if (m) {
          const style = calloutStyle(m[1]);
          push(make('callout', { style, title: m[2] || CALLOUTS[style].label, body: run(quoted.slice(1)) }), i0, i);
        } else {
          push(make('quote', { text: quoted.map(q => q[1]).join('\n') }), i0, i);
        }
        continue;
      }

      if (/^[Qq]:/.test(line)) {
        flush();
        const question = [line.slice(2).trim()];
        const answer = [];
        let inAnswer = false;
        let last = i;
        i++;
        while (i < lines.length) {
          const l = lines[i][1].trim();
          if (!l) { if (inAnswer) break; i++; continue; }
          if (/^[Aa]:/.test(l) && !inAnswer) { inAnswer = true; answer.push(l.slice(2).trim()); }
          else if (/^[Qq]:/.test(l)) break;
          else (inAnswer ? answer : question).push(l);
          last = i;
          i++;
        }
        push(make('flashcard', { question: question.join(' '), answer: answer.join('\n') }), i0, last + 1);
        i = last + 1;
        continue;
      }

      if (/^\?{1,2} /.test(line)) {
        const options = [];
        let j = i + 1;
        while (j < lines.length && quizOption(lines[j][1])) options.push(quizOption(lines[j++][1]));
        if (options.length) {
          flush();
          i = j;
          push(make('quiz', { question: line.replace(/^\?+\s*/, ''), options }), i0, i);
          continue;
        }
      }

      if (line.startsWith('|') && i + 1 < lines.length && isTableSep(lines[i + 1][1])) {
        flush();
        const header = cells(line);
        const rows = [];
        i += 2;
        while (i < lines.length && lines[i][1].trim().startsWith('|')) rows.push(cells(lines[i++][1]));
        push(make('table', { header, rows }), i0, i);
        continue;
      }

      const first = listMarker(raw);
      if (first) {
        flush();
        const items = [];
        let marker;
        while (i < lines.length && (marker = listMarker(lines[i][1])) && marker.ordered === first.ordered) {
          items.push({ ...marker, line: lines[i][0] });
          i++;
        }
        push(make('list', { items, ordered: first.ordered }), i0, i);
        continue;
      }

      const img = /^!\[(.*?)\]\((.+)\)$/.exec(line);
      if (img) { flush(); i++; push(make('image', { alt: img[1], src: img[2] }), i0, i); continue; }

      const def = line.indexOf(' :: ');
      if (def > 0) {
        flush();
        i++;
        push(make('definition', { term: line.slice(0, def).trim(), meaning: line.slice(def + 4).trim() }), i0, i);
        continue;
      }

      if (!para.length) paraStart = lineNo;
      paraEnd = lineNo;
      para.push(line);
      i++;
    }
    flush();
    return blocks;
  }
  return run(lines);
}

// ---------- Inline ----------

const PAIRS = [['`', '`'], ['{{', '}}'], ['**', '**'], ['__', '__'], ['~~', '~~'], ['==', '=='], ['++', '++'], ['^^', '^^'], ['*', '*'], ['_', '_']];

/** Inline Markdown to HTML. Supports **bold**, *italic*, ~~strike~~, `code`,
 *  ==highlight==, ++underline++, ^^small caps^^, {red|colour}, {{gap}}, [links](url). */
export function renderInline(s) {
  let out = '';
  let buf = '';
  let i = 0;
  const flush = () => { out += esc(buf); buf = ''; };
  outer: while (i < s.length) {
    const rest = s.slice(i);
    if (rest[0] === '\\' && rest.length > 1) { buf += rest[1]; i += 2; continue; }

    const link = /^\[([^\]]+)\]\(([^)\s]+)\)/.exec(rest);
    if (link) {
      flush();
      const href = /^(https?:|mailto:|#)/.test(link[2]) ? link[2] : '#';
      out += `<a href="${esc(href)}" target="_blank" rel="noopener">${renderInline(link[1])}</a>`;
      i += link[0].length;
      continue;
    }
    const color = /^\{(\w+)\|([^}]*)\}/.exec(rest);
    if (color && !rest.startsWith('{{') && COLORS[color[1].toLowerCase()]) {
      flush();
      out += `<span style="color:${COLORS[color[1].toLowerCase()]}">${renderInline(color[2])}</span>`;
      i += color[0].length;
      continue;
    }
    for (const [open, close] of PAIRS) {
      if (!rest.startsWith(open)) continue;
      const start = open.length;
      if (start >= rest.length || (/\s/.test(rest[start]) && open !== '`')) continue;
      const end = rest.indexOf(close, start);
      if (end <= start) continue;
      if (open === '_' && i > 0 && /\w/.test(s[i - 1])) continue;
      flush();
      const inner = rest.slice(start, end);
      switch (open) {
        case '`': out += `<code>${esc(inner)}</code>`; break;
        case '{{': out += `<span class="gap"><span>${renderInline(inner)}</span></span>`; break;
        case '**': case '__': out += `<strong>${renderInline(inner)}</strong>`; break;
        case '~~': out += `<s>${renderInline(inner)}</s>`; break;
        case '==': out += `<mark>${renderInline(inner)}</mark>`; break;
        case '++': out += `<u>${renderInline(inner)}</u>`; break;
        case '^^': out += `<span class="caps">${renderInline(inner)}</span>`; break;
        default: out += `<em>${renderInline(inner)}</em>`;
      }
      i += end + close.length;
      continue outer;
    }
    buf += s[i++];
  }
  flush();
  return out;
}

export const plain = s => renderInline(s).replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"');

// ---------- Study cards ----------

export function studyCards(blocks) {
  const cards = [];
  for (const b of blocks) {
    if (b.type === 'flashcard') cards.push({ kind: 'Flashcard', front: b.question, back: b.answer });
    else if (b.type === 'definition') cards.push({ kind: 'Definition', front: b.term, back: b.meaning });
    else if (b.type === 'quiz') cards.push({ kind: 'Quiz', front: b.question, back: b.options.filter(o => o.correct).map(o => o.text).join('\n'), options: b.options });
    else if (b.type === 'paragraph' && b.text.includes('{{')) cards.push({ kind: 'Fill the gap', front: b.text, back: b.text });
    else if (b.type === 'list') b.items.filter(it => it.text.includes('{{')).forEach(it => cards.push({ kind: 'Fill the gap', front: it.text, back: it.text }));
    else if (b.type === 'callout' || b.type === 'toggle') cards.push(...studyCards(b.body));
  }
  return cards.map(c => ({ ...c, id: c.front + '→' + c.back }));
}
