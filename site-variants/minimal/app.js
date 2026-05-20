// Variant: minimal — listado bibliográfico, expand-inline al click.
'use strict';

const state = { papers: [], q: '' };
const PAPERS_URL = 'data/papers.json';

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])
  );

const primerAutor = (p) => {
  const a = (p.authors || [])[0] || '';
  const apellido = a.split(',')[0] || a;
  return apellido + ((p.authors || []).length > 1 ? ' et al.' : '');
};

function matches(p, q) {
  if (!q) return true;
  const hay = [
    p.title, p.abstract, (p.authors || []).join(' '),
    (p.tags || []).join(' '), (p.key_findings || []).join(' '),
    p.journal, p.source, String(p.year ?? ''),
  ].filter(Boolean).join(' ').toLowerCase();
  return hay.includes(q);
}

function render() {
  const q = state.q.trim().toLowerCase();
  const sorted = [...state.papers]
    .filter((p) => matches(p, q))
    .sort((a, b) =>
      (b.year || 0) - (a.year || 0) ||
      (a.title || '').localeCompare(b.title || '')
    );

  const ol = document.getElementById('papers');
  ol.innerHTML = '';
  for (const p of sorted) {
    const li = document.createElement('li');
    const venue = p.journal || p.source || '';
    const findings = (p.key_findings || []).filter(Boolean);
    li.innerHTML = `
      <details>
        <summary>
          <span class="title">${esc(p.title)}</span>${p.read ? '<span class="read-mark">✓</span>' : ''}
          <span class="meta">${esc(primerAutor(p))}${p.year ? ', ' + p.year : ''}${venue ? '. ' + esc(venue) : ''}</span>
        </summary>
        <div class="detail">
          ${p.abstract ? `<p class="abstract">${esc(p.abstract)}</p>` : ''}
          ${findings.length ? `<ul class="findings">${findings.map((f) => `<li>${esc(f)}</li>`).join('')}</ul>` : ''}
          ${(p.tags || []).length ? `<div class="tags">${(p.tags || []).map(esc).join(' · ')}</div>` : ''}
          <div class="links">
            ${p.url ? `<a href="${esc(p.url)}" target="_blank" rel="noopener">enlace</a>` : ''}
            ${p.has_pdf ? `<a href="data/pdfs/${esc(p.slug)}.pdf" target="_blank" rel="noopener">pdf</a>` : ''}
          </div>
        </div>
      </details>
    `;
    ol.appendChild(li);
  }
}

async function load() {
  const r = await fetch(PAPERS_URL, { cache: 'no-cache' });
  state.papers = await r.json();
  render();
}

document.getElementById('q').addEventListener('input', (e) => {
  state.q = e.target.value;
  render();
});

load();
