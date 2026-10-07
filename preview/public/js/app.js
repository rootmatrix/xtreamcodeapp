(() => {
  const app = document.getElementById('app');
  const state = {
    token: localStorage.getItem('nexora.token') || '',
    demo: localStorage.getItem('nexora.demo') === '1',
    user: JSON.parse(localStorage.getItem('nexora.user') || 'null'),
    creds: JSON.parse(localStorage.getItem('nexora.creds') || 'null'),
    tab: 'home',
    catalogs: null,
    loading: false,
    error: '',
    detail: null,
    player: null,
    liveCat: '',
    liveChannel: null,
    epg: [],
    movieCat: 0,
    seriesCat: 0,
    query: '',
    favorites: JSON.parse(localStorage.getItem('nexora.favs') || '[]'),
    history: JSON.parse(localStorage.getItem('nexora.hist') || '[]'),
  };

  let media = { video: null, hls: null, ts: null, hideTimer: null };

  const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[ch]));

  const img = (url) => {
    if (!url) return '';
    if (url.startsWith('/assets/') || url.startsWith('data:')) return url;
    if (url.startsWith('https://')) return url;
    return `/api/img?u=${encodeURIComponent(url)}`;
  };

  const posterOf = (item) => item.stream_icon || item.cover || item.movie_image || item.poster || '';
  const idOf = (item, kind) => Number(kind === 'series' ? item.series_id : item.stream_id || item.id);
  const titleOf = (item) => item.name || item.title || 'Sin título';

  const saveLib = () => {
    localStorage.setItem('nexora.favs', JSON.stringify(state.favorites));
    localStorage.setItem('nexora.hist', JSON.stringify(state.history));
  };

  const favKey = (kind, id) => `${kind}:${id}`;
  const isFav = (kind, id) => state.favorites.some((item) => item.key === favKey(kind, id));
  const toggleFav = (kind, item) => {
    const id = idOf(item, kind);
    const key = favKey(kind, id);
    if (isFav(kind, id)) {
      state.favorites = state.favorites.filter((entry) => entry.key !== key);
    } else {
      state.favorites.unshift({
        key, kind, id, title: titleOf(item), poster: posterOf(item),
        extension: item.container_extension || 'mp4',
      });
    }
    saveLib();
    render();
  };

  async function api(action, extra = {}) {
    const params = new URLSearchParams({ action, ...extra });
    const res = await fetch(`/api/xtream?${params}`, {
      headers: { Authorization: `Bearer ${state.token}` },
    });
    if (res.status === 401) {
      logout(false);
      throw new Error('Sesión caducada');
    }
    return res.json();
  }

  async function login(server, username, password, demo = false) {
    const res = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ server, username, password, demo }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'No se pudo entrar');
    state.token = data.token;
    state.demo = !!data.demo;
    state.user = data.user_info;
    state.creds = demo ? { server: 'demo', username: 'demo' } : { server, username };
    localStorage.setItem('nexora.token', data.token);
    localStorage.setItem('nexora.demo', state.demo ? '1' : '0');
    localStorage.setItem('nexora.user', JSON.stringify(data.user_info));
    localStorage.setItem('nexora.creds', JSON.stringify(state.creds));
    await loadCatalogs();
  }

  function logout(clearCreds = true) {
    destroyPlayer();
    state.token = '';
    state.catalogs = null;
    state.detail = null;
    state.player = null;
    localStorage.removeItem('nexora.token');
    if (clearCreds) {
      localStorage.removeItem('nexora.creds');
      localStorage.removeItem('nexora.user');
    }
    render();
  }

  async function loadCatalogs() {
    state.loading = true;
    state.error = '';
    render();
    try {
      const [vodCats, seriesCats, liveCats, vod, series, live] = await Promise.all([
        api('get_vod_categories'),
        api('get_series_categories'),
        api('get_live_categories'),
        api('get_vod_streams'),
        api('get_series'),
        api('get_live_streams'),
      ]);
      state.catalogs = {
        vodCats: Array.isArray(vodCats) ? vodCats : [],
        seriesCats: Array.isArray(seriesCats) ? seriesCats : [],
        liveCats: Array.isArray(liveCats) ? liveCats : [],
        vod: Array.isArray(vod) ? vod : [],
        series: Array.isArray(series) ? series : [],
        live: Array.isArray(live) ? live : [],
      };
    } catch (err) {
      state.error = err.message || 'No se pudo cargar el catálogo';
    } finally {
      state.loading = false;
      render();
    }
  }

  function decodeMaybe(value) {
    if (!value) return '';
    try {
      if (/^[A-Za-z0-9+/]+=*$/.test(value) && value.length % 4 === 0 && value.length >= 8) {
        const text = atob(value);
        if (/[A-Za-zÁÉÍÓÚáéíóú]/.test(text)) return text;
      }
    } catch (_) { /* ignore */ }
    return value;
  }

  function byCat(list, key, id) {
    if (!id) return list;
    return list.filter((item) => String(item.category_id) === String(id));
  }

  function card(item, kind, extra = {}) {
    const title = titleOf(item);
    const poster = img(posterOf(item));
    const sq = kind === 'live' ? ' sq' : '';
    const progress = extra.progress != null
      ? `<div class="progress"><i style="width:${Math.round(extra.progress * 100)}%"></i></div>`
      : '';
    const art = poster
      ? `<img src="${esc(poster)}" alt="${esc(title)}" loading="lazy">`
      : `<div class="ph">${esc(title)}</div>`;
    return `<button class="card${sq}" data-kind="${kind}" data-id="${idOf(item, kind)}">
      <div class="poster">${art}${progress}</div>
      <div class="title">${esc(title)}</div>
    </button>`;
  }

  function row(title, html) {
    if (!html) return '';
    return `<section class="row"><div class="row-head"><h2>${esc(title)}</h2></div>
      <div class="strip">${html}</div></section>`;
  }

  function skeletons() {
    const cards = Array.from({ length: 8 }, () => '<div class="sk sk-card"></div>').join('');
    return `<div class="sk sk-hero"></div>
      <div class="strip">${cards}</div>
      <div class="strip" style="margin-top:24px">${cards}</div>`;
  }

  function brand(compact = false) {
    return `<div class="brand">
      <img src="/assets/brand/logo.png" alt="">
      ${compact ? '' : '<span>NEXORA</span>'}
    </div>`;
  }

  function topbar() {
    const tabs = [
      ['home', 'Inicio'],
      ['movies', 'Películas'],
      ['series', 'Series'],
      ['live', 'En vivo'],
      ['search', 'Buscar'],
    ];
    return `<header class="topbar" id="topbar">
      <button class="brand" data-tab="home" style="background:none;border:0;color:#fff">
        <img src="/assets/brand/logo.png" alt="Nexora"><span>NEXORA</span>
      </button>
      <nav class="nav">
        ${tabs.map(([id, label]) => `<button data-tab="${id}" class="${state.tab === id && !state.detail ? 'active' : ''}">${label}</button>`).join('')}
      </nav>
      <button class="icon-btn" data-tab="settings" title="Ajustes">⚙</button>
    </header>`;
  }

  function homePage() {
    const c = state.catalogs;
    const movies = [...c.vod].sort((a, b) => Number(b.rating || 0) - Number(a.rating || 0));
    const series = [...c.series].sort((a, b) => Number(b.rating || 0) - Number(a.rating || 0));
    const hero = movies[0];
    const hist = state.history.map((entry) => {
      const fake = {
        name: entry.title,
        stream_id: entry.streamId,
        series_id: entry.streamId,
        cover: entry.poster,
        stream_icon: entry.poster,
        container_extension: entry.extension,
      };
      return card(fake, entry.kind, { progress: entry.progress });
    }).join('');
    const favs = state.favorites.map((entry) => {
      const fake = { name: entry.title, stream_id: entry.id, series_id: entry.id, cover: entry.poster };
      return card(fake, entry.kind);
    }).join('');
    return `
      ${hero ? `<section class="hero">
        <img class="bg" src="${esc(img(posterOf(hero)))}" alt="">
        <div class="hero-copy">
          <div class="kicker">${esc([hero.year, hero.genre, hero.rating ? `★ ${hero.rating}` : ''].filter(Boolean).join('  ·  '))}</div>
          <h1>${esc(hero.name)}</h1>
          <p>${esc(hero.plot || 'Destacado de tu catálogo.')}</p>
          <div class="actions">
            <button class="btn" data-open-movie="${hero.stream_id}" data-play="1">▶  Reproducir</button>
            <button class="btn btn-ghost" data-open-movie="${hero.stream_id}">Más información</button>
          </div>
        </div>
      </section>` : ''}
      ${row('Continuar viendo', hist)}
      ${row('Películas populares', movies.slice(0, 24).map((item) => card(item, 'vod')).join(''))}
      ${row('Series populares', series.slice(0, 24).map((item) => card(item, 'series')).join(''))}
      ${row('Canales en vivo', c.live.slice(0, 24).map((item) => card(item, 'live')).join(''))}
      ${row('Mi lista', favs)}
    `;
  }

  function catalogPage(kind) {
    const c = state.catalogs;
    const isMovie = kind === 'vod';
    const cats = isMovie ? c.vodCats : c.seriesCats;
    const selected = isMovie ? state.movieCat : state.seriesCat;
    const catId = selected === 0 ? '' : cats[selected - 1]?.category_id;
    const items = byCat(isMovie ? c.vod : c.series, 'category_id', catId);
    const labels = ['Todas', ...cats.map((item) => item.category_name || item.name)];
    return `<div class="page-pad"><h1>${isMovie ? 'Películas' : 'Series'}</h1></div>
      <div class="chips">
        ${labels.map((label, i) => `<button class="chip ${i === selected ? 'active' : ''}" data-cat="${kind}:${i}">${esc(label)}</button>`).join('')}
      </div>
      <div class="grid">${items.map((item) => card(item, isMovie ? 'vod' : 'series')).join('')}</div>`;
  }

  function livePage() {
    const c = state.catalogs;
    const channels = byCat(c.live, 'category_id', state.liveCat);
    const selected = state.liveChannel || channels[0];
    const cats = [{ category_id: '', category_name: 'Todos' }, ...c.liveCats];
    const epgHtml = state.epg.length
      ? state.epg.map((p, i) => `<div class="epg-item">
          <time>${esc(p.start)} – ${esc(p.end)}</time>
          <div>${esc(p.title)}${i === 0 ? ' <span class="now">AHORA</span>' : ''}</div>
        </div>`).join('')
      : '<p class="empty" style="padding:12px">Sin guía para este canal.</p>';
    return `<div class="live">
      <aside class="rail">
        <h3>Categorías</h3>
        ${cats.map((cat) => `<button class="${String(state.liveCat) === String(cat.category_id) ? 'active' : ''}" data-live-cat="${esc(cat.category_id)}">${esc(cat.category_name || cat.name)}</button>`).join('')}
      </aside>
      <section>
        ${channels.map((ch) => `<button class="channel ${selected && selected.stream_id === ch.stream_id ? 'active' : ''}" data-live-id="${ch.stream_id}">
          <div class="avatar">${posterOf(ch) ? `<img src="${esc(img(posterOf(ch)))}" alt="">` : esc((ch.name || '?')[0])}</div>
          <div>
            <div>${esc(ch.name)}</div>
            <small style="color:var(--faint)">${ch.epg_channel_id ? 'EPG disponible' : 'Sin guía'}</small>
          </div>
        </button>`).join('')}
      </section>
      <aside class="epg">
        ${selected ? `<h3>Programación</h3>
          <h2 style="margin:0 8px 12px">${esc(selected.name)}</h2>
          <button class="btn btn-wide" style="margin:0 8px 16px;width:calc(100% - 16px)" data-kind="live" data-id="${selected.stream_id}" data-title="${esc(selected.name)}" data-ext="m3u8">▶  Ver ahora</button>
          ${epgHtml}` : '<p class="empty">Selecciona un canal.</p>'}
      </aside>
    </div>`;
  }

  function searchPage() {
    const q = state.query.trim().toLowerCase();
    const c = state.catalogs;
    const movies = q ? c.vod.filter((item) => titleOf(item).toLowerCase().includes(q)) : [];
    const series = q ? c.series.filter((item) => titleOf(item).toLowerCase().includes(q)) : [];
    const live = q ? c.live.filter((item) => titleOf(item).toLowerCase().includes(q)) : [];
    return `<div class="page-pad">
      <h1>Buscar</h1>
      <input class="search-box" id="searchInput" type="search" placeholder="Películas, series o canales" value="${esc(state.query)}">
    </div>
    ${!q ? '<p class="empty">Escribe un título para buscar en todo el catálogo.</p>' : ''}
    ${q && !movies.length && !series.length && !live.length ? '<p class="empty">Sin resultados.</p>' : ''}
    ${row(`Películas (${movies.length})`, movies.slice(0, 40).map((item) => card(item, 'vod')).join(''))}
    ${row(`Series (${series.length})`, series.slice(0, 40).map((item) => card(item, 'series')).join(''))}
    ${row(`En vivo (${live.length})`, live.slice(0, 40).map((item) => card(item, 'live')).join(''))}`;
  }

  function settingsPage() {
    const user = state.user || {};
    const exp = user.exp_date ? new Date(Number(user.exp_date) * 1000).toLocaleDateString() : '—';
    return `<div class="page-pad settings">
      <h1>Ajustes</h1>
      <div class="panel">
        <h3>Cuenta</h3>
        <div class="kv"><span>Usuario</span><b>${esc(user.username || '—')}</b></div>
        <div class="kv"><span>Estado</span><b>${esc(user.status || '—')}</b></div>
        <div class="kv"><span>Caducidad</span><b>${esc(exp)}</b></div>
        <div class="kv"><span>Conexiones</span><b>${esc(user.active_cons || '0')} / ${esc(user.max_connections || '—')}</b></div>
        <div class="kv"><span>Servidor</span><b>${esc(state.creds?.server || '—')}</b></div>
      </div>
      <div class="panel">
        <h3>Aplicación</h3>
        <div class="kv"><span>Versión</span><b>1.0.0</b></div>
        <div class="kv"><span>Motor</span><b>Xtream Codes / XUI · HLS + TS</b></div>
        <div class="kv"><span>Favoritos</span><b>${state.favorites.length}</b></div>
        <div class="kv"><span>Recientes</span><b>${state.history.length}</b></div>
      </div>
      <button class="btn btn-ghost" id="clearCache">Limpiar caché, favoritos y recientes</button>
      <div style="height:10px"></div>
      <button class="btn" id="logoutBtn">Cambiar de cuenta</button>
    </div>`;
  }

  function movieDetail(item, info) {
    const plot = info?.info?.plot || item.plot || 'Sin sinopsis disponible.';
    const rating = info?.info?.rating || item.rating;
    const year = info?.info?.year || item.year;
    const genre = info?.info?.genre || item.genre;
    const fav = isFav('vod', item.stream_id);
    return `<article class="detail">
      <div class="detail-hero"><img src="${esc(img(posterOf(item)))}" alt=""></div>
      <div class="detail-body">
        <button class="btn btn-ghost" data-back>← Volver</button>
        <h1>${esc(item.name)}</h1>
        <div class="meta">
          ${year ? `<span class="pill">${esc(year)}</span>` : ''}
          ${rating ? `<span class="pill">★ ${esc(rating)}</span>` : ''}
          ${genre ? `<span class="pill">${esc(genre)}</span>` : ''}
        </div>
        <div class="actions">
          <button class="btn" data-kind="vod" data-id="${item.stream_id}" data-ext="${esc(item.container_extension || 'mp4')}">▶  Reproducir</button>
          <button class="btn btn-ghost" data-fav="vod:${item.stream_id}">${fav ? '✓ En mi lista' : '+ Mi lista'}</button>
        </div>
        <h3>Sinopsis</h3>
        <p style="color:var(--muted);line-height:1.55">${esc(plot)}</p>
      </div>
    </article>`;
  }

  function seriesDetail(item, info) {
    const plot = info?.info?.plot || item.plot || 'Sin sinopsis disponible.';
    const episodes = info?.episodes || {};
    const seasons = Object.keys(episodes).sort((a, b) => Number(a) - Number(b));
    const current = state.detail?.season || seasons[0];
    const list = episodes[current] || [];
    const fav = isFav('series', item.series_id);
    return `<article class="detail">
      <div class="detail-hero"><img src="${esc(img(posterOf(item)))}" alt=""></div>
      <div class="detail-body">
        <button class="btn btn-ghost" data-back>← Volver</button>
        <h1>${esc(item.name)}</h1>
        <div class="meta">
          ${item.year ? `<span class="pill">${esc(item.year)}</span>` : ''}
          ${item.rating ? `<span class="pill">★ ${esc(item.rating)}</span>` : ''}
          ${item.genre ? `<span class="pill">${esc(item.genre)}</span>` : ''}
        </div>
        <div class="actions">
          <button class="btn btn-ghost" data-fav="series:${item.series_id}">${fav ? '✓ En mi lista' : '+ Mi lista'}</button>
        </div>
        <p style="color:var(--muted);line-height:1.55">${esc(plot)}</p>
        <div class="chips" style="padding-left:0">
          ${seasons.map((s) => `<button class="chip ${String(s) === String(current) ? 'active' : ''}" data-season="${s}">T${esc(s)}</button>`).join('')}
        </div>
        <div class="episodes">
          ${list.map((ep) => `<button class="episode" data-kind="series" data-id="${ep.id}" data-ext="${esc(ep.container_extension || 'mp4')}" data-title="${esc(item.name)} · T${ep.season || current}E${ep.episode_num}">
            <b>${esc(ep.episode_num)}</b>
            <div>
              <div>${esc(ep.title || ep.info?.name || 'Episodio')}</div>
              <small style="color:var(--faint)">${esc(ep.info?.plot || '')}</small>
            </div>
            <span>▶</span>
          </button>`).join('')}
        </div>
      </div>
    </article>`;
  }

  function loginView(message = '') {
    const saved = state.creds || {};
    return `<section class="login">
      <form class="login-card" id="loginForm">
        ${brand()}
        <p class="tagline">Cine, series y televisión en vivo<br>desde tu panel Xtream Codes / XUI.</p>
        <label>URL del servidor</label>
        <input name="server" type="url" placeholder="http://dns:puerto" value="${esc(saved.server && saved.server !== 'demo' ? saved.server : '')}" autocomplete="url">
        <label>Usuario</label>
        <input name="username" type="text" value="${esc(saved.username && saved.username !== 'demo' ? saved.username : '')}" autocomplete="username">
        <label>Contraseña</label>
        <input name="password" type="password" autocomplete="current-password">
        ${message ? `<div class="error">${esc(message)}</div>` : ''}
        <button class="btn btn-wide" type="submit">Entrar</button>
        <button class="btn btn-ghost btn-wide" type="button" id="demoBtn">Ver demostración</button>
        <p class="hint">Las credenciales se envían solo a tu portal, a través del proxy local.<br>Compatible con paneles Xtream Codes y XUI.</p>
      </form>
    </section>`;
  }

  function playerView() {
    const p = state.player;
    return `<section class="player show" id="player">
      <video id="video" playsinline></video>
      <div class="chrome">
        <div class="chrome-top">
          <button class="btn btn-ghost" id="playerBack">←  ${esc(p.title)}</button>
        </div>
        <div class="chrome-bottom">
          <input id="seek" type="range" min="0" max="1000" value="0">
          <div style="display:flex;align-items:center;gap:12px;margin-top:6px">
            <button class="icon-btn" id="playBtn">❚❚</button>
            <span id="clock">00:00 / 00:00</span>
            <span id="liveBadge" class="now" style="display:none">● EN VIVO</span>
            <span style="flex:1"></span>
            <span>Vol</span>
            <input id="vol" type="range" min="0" max="1" step="0.05" value="1" style="width:120px">
            <button class="icon-btn" id="fsBtn">⛶</button>
          </div>
        </div>
      </div>
      <div class="play-center"><div class="busy" id="busy"></div></div>
    </section>`;
  }

  function render(message) {
    if (!state.token) {
      app.innerHTML = loginView(message);
      bindLogin();
      return;
    }
    if (state.player) {
      app.innerHTML = playerView();
      bindPlayer();
      return;
    }
    let body = '';
    if (state.loading && !state.catalogs) body = skeletons();
    else if (state.error && !state.catalogs) {
      body = `<p class="empty">${esc(state.error)}<br><br><button class="btn" id="retry">Reintentar</button></p>`;
    } else if (state.detail?.kind === 'vod') body = movieDetail(state.detail.item, state.detail.info);
    else if (state.detail?.kind === 'series') body = seriesDetail(state.detail.item, state.detail.info);
    else if (state.tab === 'movies') body = catalogPage('vod');
    else if (state.tab === 'series') body = catalogPage('series');
    else if (state.tab === 'live') body = livePage();
    else if (state.tab === 'search') body = searchPage();
    else if (state.tab === 'settings') body = settingsPage();
    else body = homePage();

    app.innerHTML = `${topbar()}<main class="page">${body}</main>`;
    bindMain();
  }

  function bindLogin() {
    const form = document.getElementById('loginForm');
    form.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const data = new FormData(form);
      const btn = form.querySelector('[type=submit]');
      btn.disabled = true;
      try {
        await login(data.get('server'), data.get('username'), data.get('password'), false);
        render();
      } catch (err) {
        render(err.message);
      }
    });
    document.getElementById('demoBtn').addEventListener('click', async () => {
      try {
        await login('demo', 'demo', 'demo', true);
        render();
      } catch (err) {
        render(err.message);
      }
    });
  }

  function bindMain() {
    document.querySelectorAll('[data-tab]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.tab = btn.getAttribute('data-tab');
        state.detail = null;
        render();
      });
    });
    document.querySelectorAll('.card').forEach((el) => {
      el.addEventListener('click', () => onCard(el.dataset.kind, Number(el.dataset.id)));
    });
    document.querySelectorAll('[data-open-movie]').forEach((el) => {
      el.addEventListener('click', () => {
        const item = state.catalogs.vod.find((m) => m.stream_id == el.dataset.openMovie);
        if (!item) return;
        if (el.dataset.play) openPlayer({ kind: 'vod', id: item.stream_id, title: item.name, ext: item.container_extension || 'mp4', poster: posterOf(item) });
        else openMovie(item);
      });
    });
    document.querySelectorAll('[data-cat]').forEach((el) => {
      el.addEventListener('click', () => {
        const [kind, index] = el.dataset.cat.split(':');
        if (kind === 'vod') state.movieCat = Number(index);
        else state.seriesCat = Number(index);
        render();
      });
    });
    document.querySelectorAll('[data-live-cat]').forEach((el) => {
      el.addEventListener('click', () => {
        state.liveCat = el.dataset.liveCat;
        state.liveChannel = null;
        render();
      });
    });
    document.querySelectorAll('[data-live-id]').forEach((el) => {
      el.addEventListener('click', async () => {
        const ch = state.catalogs.live.find((item) => item.stream_id == el.dataset.liveId);
        state.liveChannel = ch;
        await loadEpg(ch);
        render();
      });
    });
    document.querySelectorAll('[data-kind][data-id]').forEach((el) => {
      if (el.classList.contains('card')) return;
      el.addEventListener('click', () => {
        openPlayer({
          kind: el.dataset.kind,
          id: Number(el.dataset.id),
          title: el.dataset.title || el.textContent.trim(),
          ext: el.dataset.ext || 'mp4',
        });
      });
    });
    document.querySelectorAll('[data-fav]').forEach((el) => {
      el.addEventListener('click', () => {
        const [kind, id] = el.dataset.fav.split(':');
        const item = kind === 'series'
          ? state.catalogs.series.find((s) => s.series_id == id)
          : state.catalogs.vod.find((m) => m.stream_id == id);
        if (item) toggleFav(kind, item);
      });
    });
    document.querySelectorAll('[data-season]').forEach((el) => {
      el.addEventListener('click', () => {
        state.detail.season = el.dataset.season;
        render();
      });
    });
    document.querySelectorAll('[data-back]').forEach((el) => {
      el.addEventListener('click', () => { state.detail = null; render(); });
    });
    const search = document.getElementById('searchInput');
    if (search) {
      search.focus();
      search.addEventListener('input', () => {
        state.query = search.value;
        const pos = search.selectionStart;
        render();
        const next = document.getElementById('searchInput');
        if (next) {
          next.focus();
          next.setSelectionRange(pos, pos);
        }
      });
    }
    document.getElementById('logoutBtn')?.addEventListener('click', () => logout(true));
    document.getElementById('clearCache')?.addEventListener('click', () => {
      state.favorites = [];
      state.history = [];
      saveLib();
      render();
    });
    document.getElementById('retry')?.addEventListener('click', loadCatalogs);
    if (state.tab === 'live' && !state.liveChannel && state.catalogs.live[0] && !state.epg.length) {
      state.liveChannel = byCat(state.catalogs.live, 'category_id', state.liveCat)[0];
      if (state.liveChannel) loadEpg(state.liveChannel).then(render);
    }
  }

  async function onCard(kind, id) {
    if (kind === 'live') {
      const item = state.catalogs.live.find((ch) => ch.stream_id == id) || state.favorites.find((f) => f.id == id);
      const title = item?.name || item?.title || 'En vivo';
      openPlayer({ kind: 'live', id, title, ext: 'm3u8', poster: item && posterOf(item) });
      return;
    }
    if (kind === 'vod') {
      const item = state.catalogs.vod.find((m) => m.stream_id == id);
      if (item) return openMovie(item);
      const fav = state.favorites.find((f) => f.kind === 'vod' && f.id == id);
      if (fav) openPlayer({ kind: 'vod', id, title: fav.title, ext: fav.extension || 'mp4', poster: fav.poster });
      return;
    }
    if (kind === 'series') {
      const item = state.catalogs.series.find((s) => s.series_id == id);
      if (item) return openSeries(item);
    }
  }

  async function openMovie(item) {
    state.detail = { kind: 'vod', item, info: null };
    render();
    try {
      const info = await api('get_vod_info', { vod_id: item.stream_id });
      state.detail.info = info;
      render();
    } catch (_) { /* keep list data */ }
  }

  async function openSeries(item) {
    state.detail = { kind: 'series', item, info: null };
    render();
    try {
      const info = await api('get_series_info', { series_id: item.series_id });
      state.detail.info = info;
      state.detail.season = Object.keys(info.episodes || {})[0];
      render();
    } catch (_) { /* keep list data */ }
  }

  async function loadEpg(channel) {
    try {
      const data = await api('get_short_epg', { stream_id: channel.stream_id, limit: 6 });
      const list = Array.isArray(data) ? data : (data.epg_listings || []);
      state.epg = list.map((row) => {
        const start = Number(row.start_timestamp || row.start) * (String(row.start_timestamp || row.start).length > 10 ? 1 : 1000);
        const end = Number(row.end_timestamp || row.end) * (String(row.end_timestamp || row.end).length > 10 ? 1 : 1000);
        const fmt = (ms) => new Date(ms).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        return {
          title: decodeMaybe(row.title || row.name || 'Programa'),
          start: fmt(start),
          end: fmt(end),
        };
      });
    } catch (_) {
      state.epg = [];
    }
  }

  function mediaUrl(kind, id, ext) {
    const params = new URLSearchParams({
      token: state.token,
      kind: kind === 'series' ? 'series' : kind === 'live' ? 'live' : 'movie',
      id: String(id),
      ext,
    });
    return `/api/media?${params}`;
  }

  function destroyPlayer() {
    try { media.hls?.destroy(); } catch (_) {}
    try { media.ts?.destroy(); } catch (_) {}
    if (media.video) {
      media.video.pause();
      media.video.removeAttribute('src');
      media.video.load();
    }
    media = { video: null, hls: null, ts: null, hideTimer: null };
  }

  function openPlayer(opts) {
    state.player = opts;
    render();
  }

  function fmt(t) {
    if (!Number.isFinite(t)) return '00:00';
    const h = Math.floor(t / 3600);
    const m = Math.floor((t % 3600) / 60).toString().padStart(2, '0');
    const s = Math.floor(t % 60).toString().padStart(2, '0');
    return h ? `${h}:${m}:${s}` : `${m}:${s}`;
  }

  function bindPlayer() {
    const video = document.getElementById('video');
    const busy = document.getElementById('busy');
    const seek = document.getElementById('seek');
    const clock = document.getElementById('clock');
    const playBtn = document.getElementById('playBtn');
    const vol = document.getElementById('vol');
    const liveBadge = document.getElementById('liveBadge');
    const shell = document.getElementById('player');
    media.video = video;
    const p = state.player;
    const isLive = p.kind === 'live';
    if (isLive) {
      liveBadge.style.display = 'inline';
      seek.style.opacity = .35;
    }

    const chain = isLive
      ? ['m3u8', 'ts']
      : ['m3u8', p.ext || 'mp4', 'ts'];

    const tryAt = (index) => {
      if (index >= chain.length) {
        busy.style.display = 'none';
        clock.textContent = 'No se pudo reproducir (HLS y TS fallaron).';
        return;
      }
      const ext = chain[index];
      const url = mediaUrl(p.kind, p.id, ext);
      destroyAttach();
      const onFail = () => tryAt(index + 1);
      if (ext === 'm3u8' && window.Hls && Hls.isSupported()) {
        const hls = new Hls({ enableWorker: true, maxBufferLength: 30 });
        media.hls = hls;
        hls.loadSource(url);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, () => video.play().catch(() => {}));
        hls.on(Hls.Events.ERROR, (_, data) => {
          if (data.fatal) onFail();
        });
      } else if (ext === 'ts' && window.mpegts && mpegts.isSupported()) {
        const ts = mpegts.createPlayer({ type: 'mpegts', isLive, url });
        media.ts = ts;
        ts.attachMediaElement(video);
        ts.load();
        ts.play();
        ts.on(mpegts.Events.ERROR, onFail);
      } else {
        video.src = url;
        video.play().catch(onFail);
      }
    };

    function destroyAttach() {
      try { media.hls?.destroy(); } catch (_) {}
      try { media.ts?.destroy(); } catch (_) {}
      media.hls = null;
      media.ts = null;
    }

    video.addEventListener('playing', () => { busy.style.display = 'none'; });
    video.addEventListener('waiting', () => { busy.style.display = 'block'; });
    video.addEventListener('timeupdate', () => {
      if (!isLive && video.duration) {
        seek.value = String((video.currentTime / video.duration) * 1000);
        clock.textContent = `${fmt(video.currentTime)} / ${fmt(video.duration)}`;
      } else {
        clock.textContent = fmt(video.currentTime);
      }
    });
    video.addEventListener('error', () => {});
    seek.addEventListener('input', () => {
      if (!video.duration) return;
      video.currentTime = (Number(seek.value) / 1000) * video.duration;
    });
    playBtn.addEventListener('click', () => {
      if (video.paused) video.play(); else video.pause();
      playBtn.textContent = video.paused ? '▶' : '❚❚';
    });
    vol.addEventListener('input', () => { video.volume = Number(vol.value); });
    document.getElementById('fsBtn').addEventListener('click', () => {
      if (!document.fullscreenElement) shell.requestFullscreen?.();
      else document.exitFullscreen?.();
    });
    document.getElementById('playerBack').addEventListener('click', closePlayer);
    document.addEventListener('keydown', playerKeys);
    shell.addEventListener('mousemove', () => {
      shell.classList.add('show');
      clearTimeout(media.hideTimer);
      media.hideTimer = setTimeout(() => shell.classList.remove('show'), 2800);
    });
    tryAt(0);
  }

  function playerKeys(ev) {
    if (!state.player) return;
    const video = media.video;
    if (!video) return;
    if (ev.key === 'Escape') { closePlayer(); }
    if (ev.key === ' ') { ev.preventDefault(); video.paused ? video.play() : video.pause(); }
    if (ev.key === 'f') {
      const shell = document.getElementById('player');
      if (!document.fullscreenElement) shell?.requestFullscreen?.();
      else document.exitFullscreen?.();
    }
    if (ev.key === 'ArrowRight') video.currentTime += 10;
    if (ev.key === 'ArrowLeft') video.currentTime -= 10;
  }

  function closePlayer() {
    document.removeEventListener('keydown', playerKeys);
    const video = media.video;
    if (video && state.player) {
      state.history = [{
        kind: state.player.kind,
        streamId: state.player.id,
        title: state.player.title,
        poster: state.player.poster,
        extension: state.player.ext || 'mp4',
        progress: video.duration ? video.currentTime / video.duration : 0,
      }, ...state.history.filter((h) => !(h.kind === state.player.kind && h.streamId === state.player.id))].slice(0, 40);
      saveLib();
    }
    destroyPlayer();
    state.player = null;
    render();
  }

  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape' && state.detail && !state.player) {
      state.detail = null;
      render();
    }
  });

  async function boot() {
    if (state.token) {
      try {
        await loadCatalogs();
        return;
      } catch (_) {
        state.token = '';
      }
    }
    render();
  }

  boot();
})();
