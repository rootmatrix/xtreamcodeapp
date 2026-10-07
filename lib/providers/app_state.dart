import 'package:flutter/foundation.dart';

import '../models/catalog.dart';
import '../services/local_store.dart';
import '../services/xtream_service.dart';

class AppState extends ChangeNotifier {
  AppState({LocalStore? store}) : store = store ?? LocalStore();

  final LocalStore store;

  XtreamService? xtream;
  AccountInfo? account;
  bool booting = true;
  bool loggedIn = false;
  bool loadingCatalog = false;
  String? error;

  List<Category> vodCategories = [];
  List<Category> seriesCategories = [];
  List<Category> liveCategories = [];
  List<Movie> movies = [];
  List<SeriesShow> series = [];
  List<LiveChannel> live = [];
  List<Favorite> favorites = [];
  List<WatchEntry> history = [];

  final Map<int, List<EpgProgram>> epgCache = {};

  bool get hasCatalog =>
      movies.isNotEmpty || series.isNotEmpty || live.isNotEmpty;

  Future<void> bootstrap() async {
    booting = true;
    notifyListeners();
    favorites = await store.readFavorites();
    history = await store.readHistory();
    final saved = await store.readCredentials();
    if (saved != null) {
      try {
        await login(
          saved.server,
          saved.username,
          saved.password,
          persist: false,
        );
      } catch (_) {
        loggedIn = false;
      }
    }
    booting = false;
    notifyListeners();
  }

  Future<void> login(
    String server,
    String username,
    String password, {
    bool persist = true,
  }) async {
    error = null;
    notifyListeners();
    final normalized = XtreamService.normalizeServer(server);
    final service = XtreamService(
      server: normalized,
      username: username.trim(),
      password: password,
    );
    try {
      final info = await service.authenticate();
      xtream?.close();
      xtream = service;
      account = info;
      loggedIn = true;
      if (persist) {
        await store.saveCredentials(
          SavedCredentials(
            server: normalized,
            username: username.trim(),
            password: password,
          ),
        );
      }
      notifyListeners();
      await loadCatalogs();
    } catch (err) {
      service.close();
      loggedIn = false;
      error = err.toString().replaceFirst('XtreamException: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadCatalogs() async {
    final client = xtream;
    if (client == null) return;
    loadingCatalog = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        client.vodCategories(),
        client.seriesCategories(),
        client.liveCategories(),
        client.vodStreams(),
        client.seriesList(),
        client.liveStreams(),
      ]);
      vodCategories = results[0] as List<Category>;
      seriesCategories = results[1] as List<Category>;
      liveCategories = results[2] as List<Category>;
      movies = results[3] as List<Movie>;
      series = results[4] as List<SeriesShow>;
      live = results[5] as List<LiveChannel>;
    } catch (err) {
      error = 'No se pudo cargar el catálogo: $err';
    } finally {
      loadingCatalog = false;
      notifyListeners();
    }
  }

  List<Movie> moviesByCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return movies;
    return movies.where((item) => item.categoryId == categoryId).toList();
  }

  List<SeriesShow> seriesByCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return series;
    return series.where((item) => item.categoryId == categoryId).toList();
  }

  List<LiveChannel> liveByCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return live;
    return live.where((item) => item.categoryId == categoryId).toList();
  }

  List<Movie> get popularMovies {
    final ranked = [...movies]..sort((a, b) {
        final rating = (b.rating ?? 0).compareTo(a.rating ?? 0);
        if (rating != 0) return rating;
        return (b.added ?? '').compareTo(a.added ?? '');
      });
    return ranked.take(24).toList();
  }

  List<SeriesShow> get popularSeries {
    final ranked = [...series]..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return ranked.take(24).toList();
  }

  List<LiveChannel> get featuredLive => live.take(24).toList();

  Movie? movieById(int id) {
    for (final item in movies) {
      if (item.streamId == id) return item;
    }
    return null;
  }

  SeriesShow? seriesById(int id) {
    for (final item in series) {
      if (item.seriesId == id) return item;
    }
    return null;
  }

  LiveChannel? liveById(int id) {
    for (final item in live) {
      if (item.streamId == id) return item;
    }
    return null;
  }

  List<T> search<T>(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      ...movies.where((item) => item.name.toLowerCase().contains(q)),
      ...series.where((item) => item.name.toLowerCase().contains(q)),
      ...live.where((item) => item.name.toLowerCase().contains(q)),
    ].cast<T>();
  }

  List<Object> searchAll(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      ...movies.where((item) => item.name.toLowerCase().contains(q)),
      ...series.where((item) => item.name.toLowerCase().contains(q)),
      ...live.where((item) => item.name.toLowerCase().contains(q)),
    ];
  }

  bool isFavorite(MediaKind kind, int id) {
    final key = _favKey(kind, id);
    return favorites.any((item) => item.key == key);
  }

  Future<void> toggleFavorite({
    required MediaKind kind,
    required int id,
    required String title,
    String? posterUrl,
    String? extension,
    String? categoryId,
  }) async {
    final key = _favKey(kind, id);
    final exists = favorites.any((item) => item.key == key);
    if (exists) {
      favorites = favorites.where((item) => item.key != key).toList();
    } else {
      favorites = [
        Favorite(
          key: key,
          kind: kind,
          id: id,
          title: title,
          posterUrl: posterUrl,
          extension: extension,
          categoryId: categoryId,
        ),
        ...favorites,
      ];
    }
    await store.saveFavorites(favorites);
    notifyListeners();
  }

  Future<void> upsertHistory(WatchEntry entry) async {
    history = [
      entry,
      ...history.where((item) => item.key != entry.key),
    ].take(40).toList();
    await store.saveHistory(history);
    notifyListeners();
  }

  WatchEntry? historyFor(String key) {
    for (final item in history) {
      if (item.key == key) return item;
    }
    return null;
  }

  Future<List<EpgProgram>> epgFor(LiveChannel channel) async {
    final cached = epgCache[channel.streamId];
    if (cached != null) return cached;
    try {
      final programs = await xtream!.shortEpg(channel);
      epgCache[channel.streamId] = programs;
      return programs;
    } catch (_) {
      return const [];
    }
  }

  Future<void> logout() async {
    xtream?.close();
    xtream = null;
    account = null;
    loggedIn = false;
    movies = [];
    series = [];
    live = [];
    vodCategories = [];
    seriesCategories = [];
    liveCategories = [];
    epgCache.clear();
    await store.clearCredentials();
    notifyListeners();
  }

  Future<void> clearLocalCache() async {
    favorites = [];
    history = [];
    epgCache.clear();
    await store.clearCache();
    notifyListeners();
  }

  String _favKey(MediaKind kind, int id) => '${kind.name}:$id';
}
