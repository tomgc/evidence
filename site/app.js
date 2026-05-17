// evidence — app.js
// Carga papers.json, renderiza lista, búsqueda, filtros, detalle y citas.
// Sin dependencias externas. Datos vienen de data/papers.json.

'use strict';

const DATA_URL = 'data/papers.json';
const LANG_KEY = 'evidence.lang';

const I18N = {
  es: {
    search_label: 'Buscar',
    search_placeholder: 'Buscar título, autor, tag, notas…',
    tags_heading: 'Tags',
    status_heading: 'Estado',
    status_all: 'Todos',
    status_toread: 'Por leer',
    status_reading: 'Leyendo',
    status_read: 'Leído',
    status_archived: 'Archivado',
    empty_state: 'No hay papers que coincidan con los filtros.',
    count: (n) => `${n} paper${n === 1 ? '' : 's'}`,
    section_abstract: 'Abstract',
    section_findings: 'Hallazgos clave',
    section_takeaway: 'Mi conclusión',
    section_notes: 'Notas',
    section_meta: 'Metadatos',
    section_cite: 'Citar',
    label_year: 'Año',
    label_source: 'Tipo',
    label_journal: 'Publicación',
    label_doi: 'DOI',
    label_url: 'URL',
    label_relevance: 'Relevancia',
    label_added: 'Agregado',
    label_status: 'Estado',
    action_pdf: 'Abrir PDF',
    action_link: 'Abrir enlace',
    copy: 'Copiar',
    copied: 'Copiado',
    lang_toggle: 'EN',
  },
  en: {
    search_label: 'Search',
    search_placeholder: 'Search title, author, tag, notes…',
    tags_heading: 'Tags',
    status_heading: 'Status',
    status_all: 'All',
    status_toread: 'To read',
    status_reading: 'Reading',
    status_read: 'Read',
    status_archived: 'Archived',
    empty_state: 'No papers match the current filters.',
    count: (n) => `${n} paper${n === 1 ? '' : 's'}`,
    section_abstract: 'Abstract',
    section_findings: 'Key findings',
    section_takeaway: 'My takeaway',
    section_notes: 'Notes',
    section_meta: 'Metadata',
    section_cite: 'Cite',
    label_year: 'Year',
    label_source: 'Type',
    label_journal: 'Venue',
    label_doi: 'DOI',
    label_url: 'URL',
    label_relevance: 'Relevance',
    label_added: 'Added',
    label_status: 'Status',
    action_pdf: 'Open PDF',
    action_link: 'Open link',
    copy: 'Copy',
    copied: 'Copied',
    lang_toggle: 'ES',
  },
};

// --- Estado ----------------------------------------------------------------
const state = {
  papers: [],
  activeTags: new Set(),
  status: '',
  query: '',
  selectedSlug: null,
  lang: 'es',
};

// --- DOM refs --------------------------------------------------------------
const $ = (sel) => document.querySelector(sel);
const els = {
  search: $('#search'),
  tagList: $('#tag-list'),
  statusFilter: $('#status-filter'),
  papers: $('#papers'),
  empty: $('#empty'),
  count: $('#count'),
  detail: $('#detail'),
  detailBody: $('#detail-body'),
  detailClose: $('#detail-close'),
  langToggle: $('#lang-toggle'),
  layout: document.querySelector('.layout'),
};

// --- i18n ------------------------------------------------------------------
function t(key) {
  return I18N[state.lang][key] ?? key;
}

function applyI18n() {
  document.documentElement.lang = state.lang;
  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.dataset.i18n;
    const val = I18N[state.lang][key];
    if (typeof val === 'string') el.textContent = val;
  });
  document.querySelectorAll('[data-i18n-attr]').forEach((el) => {
    const spec = el.dataset.i18nAttr;
    spec.split(';').forEach((pair) => {
      const [attr, key] = pair.split(':').map((s) => s.trim());
      const val = I18N[state.lang][key];
      if (typeof val === 'string') el.setAttribute(attr, val);
    });
  });
  els.langToggle.textContent = t('lang_toggle');
}

function setLang(lang) {
  state.lang = lang;
  localStorage.setItem(LANG_KEY, lang);
  applyI18n();
  render();
  if (state.selectedSlug) renderDetail(findPaper(state.selectedSlug));
}

// --- Helpers ---------------------------------------------------------------
function findPaper(slug) {
  return state.papers.find((p) => p.slug === slug);
}

// Construye el haystack searchable de un paper (lowercased).
function buildHaystack(p) {
  const parts = [
    p.title, p.abstract, p.my_takeaway, p.notes, p.source, p.journal, p.doi,
    (p.authors || []).join(' '),
    (p.tags || []).join(' '),
    (p.key_findings || []).join(' '),
    String(p.year ?? ''),
  ];
  return parts.filter(Boolean).join(' ').toLowerCase();
}

// Lista de tags únicos con conteo.
function tagCounts(papers) {
  const counts = new Map();
  for (const p of papers) {
    for (const tag of (p.tags || [])) {
      counts.set(tag, (counts.get(tag) || 0) + 1);
    }
  }
  return [...counts.entries()].sort((a, b) =>
    b[1] - a[1] || a[0].localeCompare(b[0])
  );
}

// Filtra papers según estado actual.
function filteredPapers() {
  const q = state.query.trim().toLowerCase();
  return state.papers.filter((p) => {
    if (state.status && p.status !== state.status) return false;
    if (state.activeTags.size > 0) {
      const tags = new Set(p.tags || []);
      for (const t of state.activeTags) if (!tags.has(t)) return false;
    }
    if (q && !p._haystack.includes(q)) return false;
    return true;
  });
}

// Ordena: relevancia desc, año desc, título asc.
function sortPapers(papers) {
  return [...papers].sort((a, b) => {
    if (b.relevance !== a.relevance) return (b.relevance || 0) - (a.relevance || 0);
    if (b.year !== a.year) return (b.year || 0) - (a.year || 0);
    return (a.title || '').localeCompare(b.title || '');
  });
}

// --- Render ----------------------------------------------------------------
function render() {
  const filtered = sortPapers(filteredPapers());
  renderList(filtered);
  renderTags();
  els.count.textContent = t('count')(filtered.length);
  els.empty.classList.toggle('hidden', filtered.length > 0);
}

function renderList(papers) {
  els.papers.innerHTML = '';
  const frag = document.createDocumentFragment();
  for (const p of papers) {
    const li = document.createElement('li');
    const btn = document.createElement('button');
    btn.className = 'paper-row';
    btn.type = 'button';
    btn.dataset.slug = p.slug;
    if (p.slug === state.selectedSlug) btn.classList.add('active');

    const title = document.createElement('span');
    title.className = 'paper-title';
    title.textContent = p.title || '(sin título)';
    btn.appendChild(title);

    if (p.status === 'read') {
      const badge = document.createElement('span');
      badge.className = 'status-badge read';
      badge.textContent = '✓';
      btn.appendChild(badge);
    }

    const meta = document.createElement('div');
    meta.className = 'paper-meta';
    const authorsShort = (p.authors || []).length > 0
      ? p.authors[0] + ((p.authors || []).length > 1 ? ' et al.' : '')
      : '';
    const year = p.year ? ` · ${p.year}` : '';
    meta.textContent = authorsShort + year;
    btn.appendChild(meta);

    if ((p.tags || []).length > 0) {
      const tagsBox = document.createElement('div');
      tagsBox.className = 'paper-tags';
      for (const tag of p.tags) {
        const chip = document.createElement('span');
        chip.className = 'chip';
        chip.textContent = tag;
        tagsBox.appendChild(chip);
      }
      btn.appendChild(tagsBox);
    }

    btn.addEventListener('click', () => selectPaper(p.slug));
    li.appendChild(btn);
    frag.appendChild(li);
  }
  els.papers.appendChild(frag);
}

function renderTags() {
  const counts = tagCounts(state.papers);
  els.tagList.innerHTML = '';
  for (const [tag, n] of counts) {
    const li = document.createElement('li');
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.dataset.tag = tag;
    btn.textContent = `${tag} (${n})`;
    if (state.activeTags.has(tag)) btn.classList.add('active');
    btn.addEventListener('click', () => toggleTag(tag));
    li.appendChild(btn);
    els.tagList.appendChild(li);
  }
}

// --- Detalle ---------------------------------------------------------------
function selectPaper(slug) {
  state.selectedSlug = slug;
  history.replaceState(null, '', '#' + slug);
  const p = findPaper(slug);
  if (!p) {
    closeDetail();
    return;
  }
  renderDetail(p);
  els.layout.classList.add('detail-open');
  els.detail.classList.remove('hidden');
  // Reflejar selección en la lista sin re-render completo
  document.querySelectorAll('.paper-row').forEach((el) => {
    el.classList.toggle('active', el.dataset.slug === slug);
  });
}

function closeDetail() {
  state.selectedSlug = null;
  history.replaceState(null, '', window.location.pathname + window.location.search);
  els.layout.classList.remove('detail-open');
  els.detail.classList.add('hidden');
  document.querySelectorAll('.paper-row.active').forEach((el) => el.classList.remove('active'));
}

function renderDetail(p) {
  els.detailBody.innerHTML = '';

  const h = document.createElement('h2');
  h.className = 'detail-title';
  h.textContent = p.title || '';
  els.detailBody.appendChild(h);

  if ((p.authors || []).length > 0) {
    const authors = document.createElement('p');
    authors.className = 'detail-authors';
    authors.textContent = p.authors.join(', ');
    els.detailBody.appendChild(authors);
  }

  if (p.journal || p.source || p.year) {
    const venue = document.createElement('p');
    venue.className = 'detail-venue';
    const bits = [p.journal || p.source, p.year].filter(Boolean);
    venue.textContent = bits.join(' · ');
    els.detailBody.appendChild(venue);
  }

  // Acciones (PDF + URL)
  const actions = document.createElement('div');
  actions.className = 'detail-actions';
  if (p.has_pdf) {
    const a = document.createElement('a');
    a.href = `data/pdfs/${p.slug}.pdf`;
    a.target = '_blank'; a.rel = 'noopener';
    a.textContent = t('action_pdf');
    actions.appendChild(a);
  }
  if (p.url) {
    const a = document.createElement('a');
    a.href = p.url;
    a.target = '_blank'; a.rel = 'noopener';
    a.textContent = t('action_link');
    actions.appendChild(a);
  }
  if (actions.children.length > 0) els.detailBody.appendChild(actions);

  // Abstract
  if (p.abstract) {
    els.detailBody.appendChild(makeSection(t('section_abstract'), p.abstract));
  }

  // Key findings
  if ((p.key_findings || []).length > 0) {
    const section = document.createElement('section');
    section.className = 'detail-section';
    const h3 = document.createElement('h3');
    h3.textContent = t('section_findings');
    section.appendChild(h3);
    const ul = document.createElement('ul');
    for (const f of p.key_findings) {
      const li = document.createElement('li');
      li.textContent = f;
      ul.appendChild(li);
    }
    section.appendChild(ul);
    els.detailBody.appendChild(section);
  }

  // My takeaway
  if (p.my_takeaway) {
    els.detailBody.appendChild(makeSection(t('section_takeaway'), p.my_takeaway));
  }

  // Notas
  if (p.notes) {
    els.detailBody.appendChild(makeSection(t('section_notes'), p.notes));
  }

  // Metadatos
  const metaSection = document.createElement('section');
  metaSection.className = 'detail-section';
  const metaH = document.createElement('h3');
  metaH.textContent = t('section_meta');
  metaSection.appendChild(metaH);
  const dl = document.createElement('dl');
  dl.className = 'detail-meta-grid';
  appendMeta(dl, t('label_year'), p.year);
  appendMeta(dl, t('label_source'), p.source);
  appendMeta(dl, t('label_journal'), p.journal);
  appendMeta(dl, t('label_doi'), p.doi,
    p.doi ? `https://doi.org/${p.doi}` : null);
  appendMeta(dl, t('label_url'), p.url, p.url);
  appendMeta(dl, t('label_relevance'), p.relevance ? `${p.relevance}/5` : null);
  appendMeta(dl, t('label_added'), p.added_on);
  appendMeta(dl, t('label_status'), p.status);
  metaSection.appendChild(dl);
  els.detailBody.appendChild(metaSection);

  // Citas
  const citeSection = document.createElement('section');
  citeSection.className = 'detail-section';
  const citeH = document.createElement('h3');
  citeH.textContent = t('section_cite');
  citeSection.appendChild(citeH);
  citeSection.appendChild(makeCiteBlock('APA', formatAPA(p)));
  citeSection.appendChild(makeCiteBlock('BibTeX', formatBibtex(p)));
  els.detailBody.appendChild(citeSection);
}

// Renderiza markdown si marked.js está disponible; cae a textContent si no.
function setMarkdownBody(el, text) {
  if (typeof marked !== 'undefined' && marked.parse) {
    el.innerHTML = marked.parse(text, { mangle: false, headerIds: false });
    el.classList.add('md');
  } else {
    el.textContent = text;
  }
}

function makeSection(heading, body) {
  const section = document.createElement('section');
  section.className = 'detail-section';
  const h3 = document.createElement('h3');
  h3.textContent = heading;
  section.appendChild(h3);
  const div = document.createElement('div');
  div.className = 'body';
  setMarkdownBody(div, body);
  section.appendChild(div);
  return section;
}

function appendMeta(dl, label, value, href) {
  if (value === null || value === undefined || value === '') return;
  const dt = document.createElement('dt');
  dt.textContent = label;
  const dd = document.createElement('dd');
  if (href) {
    const a = document.createElement('a');
    a.href = href; a.target = '_blank'; a.rel = 'noopener';
    a.textContent = String(value);
    dd.appendChild(a);
  } else {
    dd.textContent = String(value);
  }
  dl.appendChild(dt);
  dl.appendChild(dd);
}

function makeCiteBlock(label, text) {
  const wrap = document.createElement('div');
  wrap.style.marginTop = '0.5rem';

  const small = document.createElement('div');
  small.style.fontSize = '0.7rem';
  small.style.color = 'var(--text-muted)';
  small.style.marginBottom = '0.2rem';
  small.textContent = label;
  wrap.appendChild(small);

  const block = document.createElement('div');
  block.className = 'cite-block';
  block.textContent = text;

  const btn = document.createElement('button');
  btn.className = 'cite-copy';
  btn.type = 'button';
  btn.textContent = t('copy');
  btn.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(text);
      btn.textContent = t('copied');
      btn.classList.add('copied');
      setTimeout(() => {
        btn.textContent = t('copy');
        btn.classList.remove('copied');
      }, 1500);
    } catch (e) {
      // Fallback silencioso: seleccionar el texto.
      const range = document.createRange();
      range.selectNodeContents(block);
      const sel = window.getSelection();
      sel.removeAllRanges(); sel.addRange(range);
    }
  });
  block.appendChild(btn);
  wrap.appendChild(block);
  return wrap;
}

// --- Citas -----------------------------------------------------------------
function authorInitial(name) {
  // "Vaswani, Ashish" → "A."
  // "Ashish Vaswani" → "A."
  let first;
  if (name.includes(',')) {
    first = name.split(',')[1]?.trim() || '';
  } else {
    const parts = name.trim().split(/\s+/);
    first = parts[0] || '';
  }
  return first ? first.charAt(0) + '.' : '';
}

function authorLast(name) {
  if (name.includes(',')) return name.split(',')[0].trim();
  const parts = name.trim().split(/\s+/);
  return parts[parts.length - 1] || name;
}

function formatAPA(p) {
  const authors = (p.authors || []).map((a) => `${authorLast(a)}, ${authorInitial(a)}`);
  let authorsStr = '';
  if (authors.length === 1) authorsStr = authors[0];
  else if (authors.length > 1) {
    authorsStr = authors.slice(0, -1).join(', ') + ', & ' + authors[authors.length - 1];
  }
  const year = p.year ? ` (${p.year}).` : '';
  const title = p.title ? ` ${p.title}.` : '';
  const venue = p.journal ? ` ${p.journal}.` : (p.source ? ` ${p.source}.` : '');
  const doi = p.doi ? ` https://doi.org/${p.doi}` : (p.url ? ` ${p.url}` : '');
  return `${authorsStr}${year}${title}${venue}${doi}`.trim();
}

function formatBibtex(p) {
  const type = p.journal ? 'article' : 'misc';
  const lines = [`@${type}{${p.slug},`];
  const authors = (p.authors || []).join(' and ');
  if (authors) lines.push(`  author    = {${authors}},`);
  if (p.title) lines.push(`  title     = {${p.title}},`);
  if (p.year) lines.push(`  year      = {${p.year}},`);
  if (p.journal) lines.push(`  journal   = {${p.journal}},`);
  if (p.doi) lines.push(`  doi       = {${p.doi}},`);
  if (p.url) lines.push(`  url       = {${p.url}},`);
  // Quitar coma final de la última línea de campo
  if (lines.length > 1) {
    const last = lines.length - 1;
    lines[last] = lines[last].replace(/,\s*$/, '');
  }
  lines.push('}');
  return lines.join('\n');
}

// --- Interacción -----------------------------------------------------------
function toggleTag(tag) {
  if (state.activeTags.has(tag)) state.activeTags.delete(tag);
  else state.activeTags.add(tag);
  render();
}

let searchDebounce;
function onSearchInput(e) {
  clearTimeout(searchDebounce);
  searchDebounce = setTimeout(() => {
    state.query = e.target.value;
    render();
  }, 80);
}

function onStatusChange(e) {
  state.status = e.target.value;
  render();
}

function onKeyDown(e) {
  if (e.key === 'Escape' && state.selectedSlug) closeDetail();
}

// --- Bootstrap -------------------------------------------------------------
async function init() {
  // Idioma
  const saved = localStorage.getItem(LANG_KEY);
  if (saved === 'es' || saved === 'en') state.lang = saved;
  applyI18n();

  // Listeners
  els.search.addEventListener('input', onSearchInput);
  els.statusFilter.addEventListener('change', onStatusChange);
  els.detailClose.addEventListener('click', closeDetail);
  els.langToggle.addEventListener('click', () => setLang(state.lang === 'es' ? 'en' : 'es'));
  document.addEventListener('keydown', onKeyDown);

  // Data
  try {
    const res = await fetch(DATA_URL, { cache: 'no-cache' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    state.papers = data.map((p) => ({ ...p, _haystack: buildHaystack(p) }));
  } catch (err) {
    console.error('No se pudo cargar', DATA_URL, err);
    els.papers.innerHTML = `<li class="empty">Error cargando ${DATA_URL}: ${err.message}</li>`;
    return;
  }

  render();

  // Abrir paper por hash si viene en la URL
  if (window.location.hash) {
    const slug = window.location.hash.slice(1);
    if (findPaper(slug)) selectPaper(slug);
  }
}

document.addEventListener('DOMContentLoaded', init);
