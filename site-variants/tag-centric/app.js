// Variant: tag-centric — landing por temas, navegación primero por tag.
// Los tags primarios (top N por frecuencia) se renderean como cards grandes;
// el resto como chips. En producción el ranking podría sustituirse por una
// taxonomía curada en docs/taxonomy.yaml.
'use strict';

const state = {
  papers: [],
  view: 'categories', // 'categories' | 'tag' | 'detail' | 'search'
  activeTag: null,
  activeSlug: null,
};
const PAPERS_URL = 'data/papers.json';
const PRIMARY_TOP_N = 3;

const $ = (sel) => document.querySelector(sel);
const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])
  );

const primerAutor = (p) => {
  const a = (p.authors || [])[0] || '';
  const apellido = a.split(',')[0] || a;
  return apellido + ((p.authors || []).length > 1 ? ' et al.' : '');
};

function tagFrequency() {
  const counts = new Map();
  for (const p of state.papers) {
    for (const t of (p.tags || [])) counts.set(t, (counts.get(t) || 0) + 1);
  }
  return [...counts.entries()].sort(
    (a, b) => b[1] - a[1] || a[0].localeCompare(b[0])
  );
}

function setView(v) {
  state.view = v;
  $('#categories').classList.toggle('hidden', v !== 'categories');
  $('#tag-papers').classList.toggle('hidden', v !== 'tag' && v !== 'search');
  $('#detail').classList.toggle('hidden', v !== 'detail');
  $('#back').classList.toggle('hidden', v === 'categories');
  // Refleja el tag activo en la nav del header.
  document.querySelectorAll('.header-tag').forEach((el) => {
    el.classList.toggle('active', el.dataset.tag === state.activeTag);
  });
}

// Renderiza los tags en el header (atajos siempre visibles).
// Primarios (top N por frecuencia) van resaltados; el resto plano.
function renderHeaderTags() {
  const freq = tagFrequency();
  const primaryNames = new Set(freq.slice(0, PRIMARY_TOP_N).map(([t]) => t));
  const nav = $('#header-tags');
  nav.innerHTML = '';
  for (const [tag, count] of freq) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'header-tag' + (primaryNames.has(tag) ? ' primary' : '');
    btn.dataset.tag = tag;
    btn.innerHTML = `${tag}<span class="count">${count}</span>`;
    btn.addEventListener('click', () => showTagPapers(tag));
    nav.appendChild(btn);
  }
}

function showCategories() {
  setView('categories');
  state.activeTag = null;
  state.activeSlug = null;

  const freq = tagFrequency();
  const primary = freq.slice(0, PRIMARY_TOP_N);
  const secondary = freq.slice(PRIMARY_TOP_N);

  const pg = $('#primary-tags');
  pg.innerHTML = '';
  for (const [tag, count] of primary) {
    const sample = state.papers.find((p) => (p.tags || []).includes(tag));
    const card = document.createElement('div');
    card.className = 'primary-card';
    card.innerHTML = `
      <div class="tag-name">${esc(tag)}</div>
      <div class="tag-count">${count} paper${count === 1 ? '' : 's'}</div>
      ${sample ? `<div class="preview"><div class="preview-title">${esc(sample.title)}</div><div>${esc(primerAutor(sample))}${sample.year ? ', ' + sample.year : ''}</div></div>` : ''}
    `;
    card.addEventListener('click', () => showTagPapers(tag));
    pg.appendChild(card);
  }

  const sr = $('#secondary-tags');
  sr.innerHTML = '';
  if (secondary.length === 0) {
    sr.innerHTML = '<span class="muted-sub">No hay otros temas todavía.</span>';
  }
  for (const [tag, count] of secondary) {
    const chip = document.createElement('button');
    chip.className = 'secondary-chip';
    chip.type = 'button';
    chip.innerHTML = `${esc(tag)}<span class="count">${count}</span>`;
    chip.addEventListener('click', () => showTagPapers(tag));
    sr.appendChild(chip);
  }
}

function renderPapersList(papers, activeTag) {
  const list = $('#papers-list');
  list.innerHTML = '';
  for (const p of papers) {
    const card = document.createElement('li');
    card.className = 'paper-card';
    card.innerHTML = `
      <div class="title">${esc(p.title)}</div>
      <div class="authors">${esc(primerAutor(p))}${p.year ? ' · ' + p.year : ''}</div>
      <div class="mini-tags">
        ${(p.tags || [])
          .map((t) => `<span class="mini-tag${t === activeTag ? ' active' : ''}">${esc(t)}</span>`)
          .join('')}
      </div>
    `;
    card.addEventListener('click', () => showDetail(p.slug));
    list.appendChild(card);
  }
}

function showTagPapers(tag) {
  state.activeTag = tag;
  setView('tag');
  $('#tag-title').textContent = tag;
  const papers = state.papers
    .filter((p) => (p.tags || []).includes(tag))
    .sort((a, b) => (b.year || 0) - (a.year || 0));
  $('#tag-meta').textContent =
    `${papers.length} paper${papers.length === 1 ? '' : 's'} en este tema`;
  renderPapersList(papers, tag);
}

function showSearch(q) {
  state.activeTag = null;
  setView('search');
  $('#tag-title').textContent = `Búsqueda: "${q}"`;
  const ql = q.toLowerCase();
  const matches = state.papers.filter((p) => {
    const hay = [p.title, p.abstract, (p.authors || []).join(' '),
                 (p.tags || []).join(' '), (p.key_findings || []).join(' '),
                 p.notes, p.journal, p.source].filter(Boolean).join(' ').toLowerCase();
    return hay.includes(ql);
  });
  $('#tag-meta').textContent =
    `${matches.length} paper${matches.length === 1 ? '' : 's'} encontrados`;
  renderPapersList(matches, null);
}

function showDetail(slug) {
  const p = state.papers.find((x) => x.slug === slug);
  if (!p) return;
  state.activeSlug = slug;
  setView('detail');

  const venue = [p.journal || p.source, p.year].filter(Boolean).join(' · ');
  const findings = (p.key_findings || []).filter(Boolean);
  const notesHtml = p.notes
    ? (typeof marked !== 'undefined' ? marked.parse(p.notes) : esc(p.notes))
    : '';

  $('#detail').innerHTML = `
    <button class="back-btn" id="back-from-detail">← Volver</button>
    <h2 class="title">${esc(p.title)}</h2>
    <p class="muted">${esc((p.authors || []).join(', '))}</p>
    ${venue ? `<p class="muted italic">${esc(venue)}</p>` : ''}
    ${p.abstract ? `<div class="section-h">Abstract</div><div class="section-body"><p>${esc(p.abstract)}</p></div>` : ''}
    ${findings.length ? `<div class="section-h">Hallazgos clave</div><div class="section-body"><ul>${findings.map((f) => `<li>${esc(f)}</li>`).join('')}</ul></div>` : ''}
    ${notesHtml ? `<div class="section-h">Notas</div><div class="section-body">${notesHtml}</div>` : ''}
    ${(p.tags || []).length ? `<div class="detail-tags">${(p.tags || []).map((t) => `<span class="chip" data-tag="${esc(t)}">${esc(t)}</span>`).join('')}</div>` : ''}
    <div class="detail-links">
      ${p.url ? `<a href="${esc(p.url)}" target="_blank" rel="noopener">Enlace</a>` : ''}
      ${p.has_pdf ? `<a href="data/pdfs/${esc(p.slug)}.pdf" target="_blank" rel="noopener">PDF</a>` : ''}
    </div>
  `;

  $('#back-from-detail').addEventListener('click', () => {
    if (state.activeTag) showTagPapers(state.activeTag);
    else showCategories();
  });
  $('#detail').querySelectorAll('.chip').forEach((el) => {
    el.addEventListener('click', () => showTagPapers(el.dataset.tag));
  });
}

function setupListeners() {
  $('#back').addEventListener('click', () => {
    if (state.view === 'detail' && state.activeTag) showTagPapers(state.activeTag);
    else showCategories();
  });
  let qTimer;
  $('#q').addEventListener('input', (e) => {
    clearTimeout(qTimer);
    qTimer = setTimeout(() => {
      const v = e.target.value.trim();
      if (!v) showCategories();
      else showSearch(v);
    }, 80);
  });
}

async function init() {
  const r = await fetch(PAPERS_URL, { cache: 'no-cache' });
  state.papers = await r.json();
  renderHeaderTags();
  setupListeners();
  showCategories();
}

init();
