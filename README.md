# Nexora

Cliente de streaming **estilo Netflix** para paneles **Xtream Codes / XUI**.

Funciona en **móvil**, **Android TV** (mando D-pad) y escritorio. Habla con el portal a través del paquete Dart [`muxa_xtream`](https://pub.dev/packages/muxa_xtream) y de `player_api.php`.

## Qué incluye

- Login con URL del servidor, usuario y contraseña (validación contra `player_api.php`)
- Credenciales en **almacenamiento seguro** (`flutter_secure_storage`)
- Inicio con filas horizontales: Continuar viendo, populares, en vivo, Mi lista
- Películas y series por categoría, ficha con sinopsis, valoración y año
- Series con temporadas y episodios
- En vivo: categorías + canales + EPG corto
- Reproducción **HLS primero, TS de respaldo**
- Búsqueda por nombre, favoritos y recientes locales
- Ajustes: cambiar cuenta, limpiar caché, versión
- Tema oscuro con acento rojo, pósters 2:3, logos 1:1, skeletons

## Requisitos

- Flutter 3.24+ / Dart 3.3+
- Un portal Xtream Codes o XUI (o el **modo demostración** de la vista previa web)

## Arranque (app Flutter)

```bash
flutter pub get
flutter run                     # móvil / escritorio
flutter run -d android          # Android / Android TV
```

Si faltan carpetas de plataforma:

```bash
flutter create --platforms=android,ios,web,macos,windows,linux .
```

Android permite tráfico HTTP (muchos portales IPTV no usan TLS) y declara `LEANBACK_LAUNCHER` para Android TV.

## URLs de reproducción

| Tipo | HLS | Respaldo |
| --- | --- | --- |
| En vivo | `{server}/live/{user}/{pass}/{id}.m3u8` | `.ts` |
| Película | `{server}/movie/{user}/{pass}/{id}.m3u8` | `.{ext}` y `.ts` |
| Serie | `{server}/series/{user}/{pass}/{id}.m3u8` | `.{ext}` y `.ts` |

Las URLs se construyen con `liveUrl` / `vodUrl` / `seriesUrl` de `muxa_xtream`.

## Vista previa web (esta sesión)

Hay un servidor Node que replica la interfaz y **proxifica** el API Xtream (evita CORS y mixed-content):

```bash
cd preview
npm install
npm start
```

En el login puedes pulsar **Ver demostración** o entrar con tu portal real.

## Arquitectura Flutter

```
lib/
  main.dart
  theme/app_theme.dart
  models/catalog.dart
  services/xtream_service.dart   # muxa_xtream + parser robusto
  services/local_store.dart      # secure storage + preferencias
  providers/app_state.dart
  screens/                       # login, home, catálogo, live, player…
  widgets/                       # pósters, filas, skeletons, logo
```

## Licencia

MIT
