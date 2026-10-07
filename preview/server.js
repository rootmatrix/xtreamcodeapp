'use strict';

const crypto = require('crypto');
const express = require('express');
const http = require('http');
const https = require('https');
const path = require('path');
const { URL } = require('url');

const PORT = Number(process.env.PORT || 3000);
const sessions = new Map();
const app = express();

app.disable('x-powered-by');
app.use(express.json({ limit: '1mb' }));
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.use('/assets', express.static(path.join(__dirname, '../assets'), { maxAge: '7d' }));
app.use(express.static(path.join(__dirname, 'public')));

const DEMO_HLS = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

const demoMovies = [
  {
    stream_id: 101,
    name: 'Eclipse Noir',
    category_id: '1',
    stream_icon: '/assets/demo/poster_eclipse.jpg',
    cover: '/assets/demo/poster_eclipse.jpg',
    rating: 8.4,
    year: '2024',
    genre: 'Thriller',
    container_extension: 'mp4',
    plot: 'Un detective marcado por la luna de sangre persigue a un asesino que solo aparece durante los eclipses. Cada pista lo acerca a un secreto que él mismo enterró.',
    added: '1710000000',
  },
  {
    stream_id: 102,
    name: 'Neon Dynasty',
    category_id: '2',
    stream_icon: '/assets/demo/poster_neon.jpg',
    cover: '/assets/demo/poster_neon.jpg',
    rating: 7.9,
    year: '2025',
    genre: 'Acción',
    container_extension: 'mp4',
    plot: 'En una Tokio anegada de neón, una cazarrecompensas debe elegir entre el clan que la crió y la ciudad que juró proteger.',
    added: '1712000000',
  },
  {
    stream_id: 103,
    name: 'Aurora Protocol',
    category_id: '3',
    stream_icon: '/assets/demo/poster_aurora.jpg',
    cover: '/assets/demo/poster_aurora.jpg',
    rating: 8.7,
    year: '2023',
    genre: 'Ciencia ficción',
    container_extension: 'mp4',
    plot: 'La tripulación de la Aurora descubre que el protocolo de emergencia de la nave no fue escrito para salvarlos… sino para abrir una puerta.',
    added: '1705000000',
  },
  {
    stream_id: 104,
    name: 'Mar de Cristal',
    category_id: '1',
    stream_icon: '/assets/demo/poster_cristal.jpg',
    cover: '/assets/demo/poster_cristal.jpg',
    rating: 7.5,
    year: '2024',
    genre: 'Drama',
    container_extension: 'mp4',
    plot: 'Una oceanógrafa vuelve al archipiélago donde desapareció su hermana y encuentra una estructura de cristal que late con la marea.',
    added: '1709000000',
  },
  {
    stream_id: 105,
    name: 'La Última Estación',
    category_id: '4',
    stream_icon: '/assets/demo/poster_estacion.jpg',
    cover: '/assets/demo/poster_estacion.jpg',
    rating: 8.1,
    year: '2022',
    genre: 'Misterio',
    container_extension: 'mp4',
    plot: 'El expreso de medianoche se detiene en una estación que no figura en ningún mapa. Los pasajeros tienen hasta el amanecer para bajar… o quedarse para siempre.',
    added: '1690000000',
  },
];

const demoSeries = [
  {
    series_id: 201,
    name: 'Casa del Viento',
    category_id: '10',
    cover: '/assets/demo/poster_casa.jpg',
    rating: 8.6,
    year: '2024',
    genre: 'Drama',
    plot: 'Tres generaciones de una familia se enfrentan en un caserón frente al acantilado, donde el viento no es el único que habla.',
  },
  {
    series_id: 202,
    name: 'Noches de Tokio',
    category_id: '11',
    cover: '/assets/demo/poster_tokio.jpg',
    rating: 8.2,
    year: '2025',
    genre: 'Suspense',
    plot: 'Una traductora de la embajada se ve envuelta en una red de espionaje cuando un desconocido le deja una llave y un nombre.',
  },
];

const demoLive = [
  { stream_id: 301, name: 'Nexora Cinema 1', category_id: '20', stream_icon: '/assets/brand/logo.png', epg_channel_id: 'cine1' },
  { stream_id: 302, name: 'Nexora Cinema 2', category_id: '20', stream_icon: '/assets/brand/logo.png', epg_channel_id: 'cine2' },
  { stream_id: 303, name: 'Deportes 24', category_id: '21', stream_icon: '/assets/brand/logo.png', epg_channel_id: 'dep' },
  { stream_id: 304, name: 'Fútbol Now', category_id: '21', stream_icon: '/assets/brand/logo.png', epg_channel_id: 'fut' },
  { stream_id: 305, name: 'Noticias Central', category_id: '22', stream_icon: '/assets/brand/logo.png', epg_channel_id: 'news' },
  { stream_id: 306, name: 'Mundo 360', category_id: '22', stream_icon: '/assets/brand/logo.png', epg_channel_id: 'mundo' },
  { stream_id: 307, name: 'Kids Universe', category_id: '23', stream_icon: '/assets/brand/logo.png', epg_channel_id: 'kids' },
  { stream_id: 308, name: 'Music Pulse', category_id: '23', stream_icon: '/assets/brand/logo.png', epg_channel_id: 'music' },
];

function movieInfo(id) {
  const movie = demoMovies.find((item) => String(item.stream_id) === String(id)) || demoMovies[0];
  return {
    info: {
      plot: movie.plot,
      genre: movie.genre,
      rating: movie.rating,
      releasedate: `${movie.year}-01-15`,
      movie_image: movie.cover,
      duration: '01:58:00',
      year: movie.year,
    },
    movie_data: {
      stream_id: movie.stream_id,
      name: movie.name,
      container_extension: 'mp4',
      category_id: movie.category_id,
    },
  };
}

function seriesInfo(id) {
  const show = demoSeries.find((item) => String(item.series_id) === String(id)) || demoSeries[0];
  const seasons = {};
  for (let s = 1; s <= 2; s += 1) {
    seasons[s] = Array.from({ length: 6 }, (_, i) => ({
      id: Number(`${show.series_id}${s}${i + 1}`),
      title: `Capítulo ${i + 1}`,
      season: s,
      episode_num: i + 1,
      container_extension: 'mp4',
      info: {
        plot: `Temporada ${s}, episodio ${i + 1} de ${show.name}.`,
        duration: '00:48:00',
        movie_image: show.cover,
      },
    }));
  }
  return {
    info: {
      name: show.name,
      plot: show.plot,
      genre: show.genre,
      rating: show.rating,
      cover: show.cover,
      releaseDate: show.year,
    },
    episodes: seasons,
  };
}

function makeEpg(channelName = 'Canal') {
  const now = Date.now();
  const hour = 36e5;
  const titles = [
    `${channelName}: edición matinal`,
    'Cine de estreno',
    'Documental original Nexora',
    'Directo especial',
    'Serie destacada',
    'Cierre de emisión',
  ];
  return titles.map((title, i) => {
    const start = Math.floor((now - hour / 2 + i * hour) / 1000);
    return {
      title: Buffer.from(title).toString('base64'),
      description: Buffer.from('Guía de ejemplo generada por Nexora.').toString('base64'),
      start_timestamp: start,
      end_timestamp: start + 3600,
      start: String(start),
      end: String(start + 3600),
    };
  });
}

function demoPayload(action, query) {
  switch (action) {
    case 'get_vod_categories':
      return [
        { category_id: '1', category_name: 'Drama' },
        { category_id: '2', category_name: 'Acción' },
        { category_id: '3', category_name: 'Ciencia ficción' },
        { category_id: '4', category_name: 'Misterio' },
      ];
    case 'get_series_categories':
      return [
        { category_id: '10', category_name: 'Drama de prestigio' },
        { category_id: '11', category_name: 'Suspense' },
      ];
    case 'get_live_categories':
      return [
        { category_id: '20', category_name: 'Cine' },
        { category_id: '21', category_name: 'Deportes' },
        { category_id: '22', category_name: 'Noticias' },
        { category_id: '23', category_name: 'Entretenimiento' },
      ];
    case 'get_vod_streams':
      return query.category_id
        ? demoMovies.filter((item) => item.category_id === String(query.category_id))
        : demoMovies;
    case 'get_series':
      return query.category_id
        ? demoSeries.filter((item) => item.category_id === String(query.category_id))
        : demoSeries;
    case 'get_live_streams':
      return query.category_id
        ? demoLive.filter((item) => item.category_id === String(query.category_id))
        : demoLive;
    case 'get_vod_info':
      return movieInfo(query.vod_id);
    case 'get_series_info':
      return seriesInfo(query.series_id);
    case 'get_short_epg': {
      const ch = demoLive.find((item) => String(item.stream_id) === String(query.stream_id));
      return { epg_listings: makeEpg(ch ? ch.name : 'Canal') };
    }
    default:
      return [];
  }
}

function sessionFrom(req) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ')
    ? header.slice(7)
    : req.query.token;
  if (!token) return null;
  return sessions.get(String(token)) || null;
}

function fetchUrl(target, { method = 'GET', headers = {}, body, timeout = 25000 } = {}) {
  return new Promise((resolve, reject) => {
    let parsed;
    try {
      parsed = new URL(target);
    } catch (err) {
      reject(err);
      return;
    }
    const lib = parsed.protocol === 'https:' ? https : http;
    const req = lib.request(
      parsed,
      {
        method,
        headers: {
          'User-Agent': 'Nexora/1.0 (Xtream; preview)',
          Accept: '*/*',
          Connection: 'close',
          ...headers,
        },
        timeout,
        rejectUnauthorized: false,
      },
      (res) => {
        resolve(res);
      },
    );
    req.on('timeout', () => {
      req.destroy(new Error('timeout'));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function readJson(res) {
  const chunks = [];
  for await (const chunk of res) chunks.push(chunk);
  const text = Buffer.concat(chunks).toString('utf8').trim();
  if (!text) return null;
  return JSON.parse(text);
}

function normalizeServer(input) {
  let url = String(input || '').trim();
  if (!url) throw new Error('URL vacía');
  if (!/^https?:\/\//i.test(url)) url = `http://${url}`;
  while (url.endsWith('/')) url = url.slice(0, -1);
  const parsed = new URL(url);
  if (!parsed.hostname) throw new Error('URL no válida');
  return url;
}

app.post('/api/login', async (req, res) => {
  try {
    const username = String(req.body.username || '').trim();
    const password = String(req.body.password || '');
    const demo = username.toLowerCase() === 'demo' ||
      String(req.body.server || '').toLowerCase() === 'demo' ||
      req.body.demo === true;

    if (demo) {
      const token = crypto.randomBytes(16).toString('hex');
      sessions.set(token, { demo: true, username: 'demo', server: 'demo' });
      return res.json({
        token,
        demo: true,
        user_info: {
          username: 'demo',
          status: 'Active',
          auth: 1,
          exp_date: String(Math.floor(Date.now() / 1000) + 86400 * 365),
          max_connections: '2',
          active_cons: '1',
          is_trial: '0',
        },
        server_info: { url: 'demo', timezone: 'UTC' },
      });
    }

    const server = normalizeServer(req.body.server);
    const url = `${server}/player_api.php?username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
    const upstream = await fetchUrl(url);
    if (upstream.statusCode && upstream.statusCode >= 400) {
      return res.status(401).json({ error: `El portal respondió HTTP ${upstream.statusCode}` });
    }
    const data = await readJson(upstream);
    const user = data && data.user_info;
    const authOk = user && (String(user.auth) === '1' || String(user.status).toLowerCase() === 'active');
    if (!authOk) {
      return res.status(401).json({ error: 'Usuario o contraseña incorrectos.' });
    }
    const token = crypto.randomBytes(16).toString('hex');
    sessions.set(token, { demo: false, username, password, server });
    return res.json({ token, demo: false, user_info: user, server_info: data.server_info || {} });
  } catch (err) {
    return res.status(400).json({ error: err.message || 'No se pudo conectar con el portal.' });
  }
});

app.get('/api/xtream', async (req, res) => {
  const session = sessionFrom(req);
  if (!session) return res.status(401).json({ error: 'Sesión caducada. Vuelve a entrar.' });
  const action = String(req.query.action || '');
  if (session.demo) return res.json(demoPayload(action, req.query));
  try {
    const params = new URLSearchParams({
      username: session.username,
      password: session.password,
    });
    for (const [key, value] of Object.entries(req.query)) {
      if (key === 'token' || key === 'action' && !value) continue;
      if (value != null) params.set(key, String(value));
    }
    if (action) params.set('action', action);
    const url = `${session.server}/player_api.php?${params.toString()}`;
    const upstream = await fetchUrl(url, { timeout: 45000 });
    res.status(upstream.statusCode || 200);
    const type = upstream.headers['content-type'] || 'application/json';
    res.setHeader('Content-Type', type);
    upstream.pipe(res);
  } catch (err) {
    res.status(502).json({ error: err.message || 'Error de portal' });
  }
});

app.get('/api/img', async (req, res) => {
  const raw = String(req.query.u || '');
  if (!raw) return res.sendStatus(400);
  if (raw.startsWith('/assets/')) return res.redirect(raw);
  try {
    const upstream = await fetchUrl(raw, { timeout: 15000 });
    res.status(upstream.statusCode || 200);
    if (upstream.headers['content-type']) {
      res.setHeader('Content-Type', upstream.headers['content-type']);
    }
    res.setHeader('Cache-Control', 'public, max-age=86400');
    upstream.pipe(res);
  } catch {
    res.sendStatus(404);
  }
});

function streamPath(session, kind, id, ext) {
  const safeExt = String(ext || 'm3u8').replace(/[^\w.]/g, '') || 'm3u8';
  const folder = kind === 'live' ? 'live' : kind === 'series' ? 'series' : 'movie';
  return `${session.server}/${folder}/${session.username}/${session.password}/${id}.${safeExt}`;
}

function rewritePlaylist(text, playlistUrl, token) {
  const base = new URL(playlistUrl);
  return text.split(/\r?\n/).map((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      return line.replace(/URI="([^"]+)"/g, (_, uri) => {
        const abs = new URL(uri, base).href;
        return `URI="/api/media?token=${token}&u=${encodeURIComponent(abs)}"`;
      });
    }
    const abs = new URL(trimmed, base).href;
    return `/api/media?token=${token}&u=${encodeURIComponent(abs)}`;
  }).join('\n');
}

app.get('/api/media', async (req, res) => {
  const session = sessionFrom(req);
  if (!session) return res.status(401).send('unauthorized');
  let target;
  if (req.query.u) {
    target = String(req.query.u);
  } else if (session.demo) {
    target = DEMO_HLS;
  } else {
    target = streamPath(session, req.query.kind || 'live', req.query.id, req.query.ext || 'm3u8');
  }
  try {
    const headers = {};
    if (req.headers.range) headers.Range = req.headers.range;
    const upstream = await fetchUrl(target, { headers, timeout: 30000 });
    const type = String(upstream.headers['content-type'] || '');
    const isPlaylist = type.includes('mpegurl') || /\.m3u8?(\?|$)/i.test(target);
    if (isPlaylist) {
      const chunks = [];
      for await (const chunk of upstream) chunks.push(chunk);
      const text = Buffer.concat(chunks).toString('utf8');
      const rewritten = rewritePlaylist(text, target, req.query.token);
      res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
      res.setHeader('Cache-Control', 'no-cache');
      return res.send(rewritten);
    }
    res.status(upstream.statusCode || 200);
    ['content-type', 'content-length', 'accept-ranges', 'content-range'].forEach((key) => {
      if (upstream.headers[key]) res.setHeader(key, upstream.headers[key]);
    });
    upstream.pipe(res);
  } catch (err) {
    res.status(502).send(String(err.message || 'stream error'));
  }
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public/index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Nexora preview on http://0.0.0.0:${PORT}`);
});
