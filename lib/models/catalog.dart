import '../core/json_util.dart';

enum MediaKind { live, vod, series }

class Category {
  final String id;
  final String name;
  final MediaKind kind;

  const Category({required this.id, required this.name, required this.kind});

  factory Category.fromJson(Map<String, dynamic> json, MediaKind kind) {
    return Category(
      id: asString(json['category_id'] ?? json['id']) ?? '',
      name: asString(json['category_name'] ?? json['name']) ?? 'Sin categoría',
      kind: kind,
    );
  }
}

class Movie {
  final int streamId;
  final String name;
  final String categoryId;
  final String? posterUrl;
  final String? backdropUrl;
  final String extension;
  final String? plot;
  final double? rating;
  final String? year;
  final String? genre;
  final String? added;
  final int? durationSecs;

  const Movie({
    required this.streamId,
    required this.name,
    required this.categoryId,
    this.posterUrl,
    this.backdropUrl,
    this.extension = 'mp4',
    this.plot,
    this.rating,
    this.year,
    this.genre,
    this.added,
    this.durationSecs,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    final info = asMap(json['info']);
    return Movie(
      streamId: asInt(json['stream_id'] ?? json['id']) ?? 0,
      name: asString(json['name'] ?? json['title']) ?? 'Sin título',
      categoryId: asString(json['category_id'] ?? json['category']) ?? '',
      posterUrl: asString(
        json['stream_icon'] ??
            json['cover'] ??
            json['movie_image'] ??
            info['movie_image'] ??
            json['poster'],
      ),
      backdropUrl: asString(
        json['backdrop_path'] ?? json['cover_big'] ?? info['backdrop_path'],
      ),
      extension: asString(json['container_extension']) ?? 'mp4',
      plot: asString(json['plot'] ?? info['plot'] ?? json['description']),
      rating: asDouble(json['rating'] ?? json['rating_5based'] ?? info['rating']),
      year: _yearOf(json['year'] ?? json['releaseDate'] ?? json['releasedate'] ?? info['releasedate']),
      genre: asString(json['genre'] ?? info['genre']),
      added: asString(json['added']),
      durationSecs: asInt(json['duration_secs'] ?? json['duration']),
    );
  }

  Movie copyWithDetails(Movie details) => Movie(
        streamId: streamId,
        name: details.name.isNotEmpty ? details.name : name,
        categoryId: categoryId,
        posterUrl: details.posterUrl ?? posterUrl,
        backdropUrl: details.backdropUrl ?? backdropUrl,
        extension: details.extension,
        plot: details.plot ?? plot,
        rating: details.rating ?? rating,
        year: details.year ?? year,
        genre: details.genre ?? genre,
        added: added,
        durationSecs: details.durationSecs ?? durationSecs,
      );
}

class SeriesShow {
  final int seriesId;
  final String name;
  final String categoryId;
  final String? posterUrl;
  final String? backdropUrl;
  final String? plot;
  final double? rating;
  final String? year;
  final String? genre;

  const SeriesShow({
    required this.seriesId,
    required this.name,
    required this.categoryId,
    this.posterUrl,
    this.backdropUrl,
    this.plot,
    this.rating,
    this.year,
    this.genre,
  });

  factory SeriesShow.fromJson(Map<String, dynamic> json) {
    return SeriesShow(
      seriesId: asInt(json['series_id'] ?? json['id']) ?? 0,
      name: asString(json['name'] ?? json['title']) ?? 'Sin título',
      categoryId: asString(json['category_id'] ?? json['category']) ?? '',
      posterUrl: asString(json['cover'] ?? json['stream_icon'] ?? json['poster']),
      backdropUrl: asString(json['backdrop_path'] ?? json['cover_big']),
      plot: asString(json['plot'] ?? json['description']),
      rating: asDouble(json['rating'] ?? json['rating_5based']),
      year: _yearOf(json['year'] ?? json['releaseDate'] ?? json['releasedate']),
      genre: asString(json['genre']),
    );
  }
}

class LiveChannel {
  final int streamId;
  final String name;
  final String categoryId;
  final String? logoUrl;
  final String? epgChannelId;
  final bool hasEpg;

  const LiveChannel({
    required this.streamId,
    required this.name,
    required this.categoryId,
    this.logoUrl,
    this.epgChannelId,
    this.hasEpg = false,
  });

  factory LiveChannel.fromJson(Map<String, dynamic> json) {
    return LiveChannel(
      streamId: asInt(json['stream_id'] ?? json['id']) ?? 0,
      name: asString(json['name'] ?? json['title']) ?? 'Canal',
      categoryId: asString(json['category_id'] ?? json['category']) ?? '',
      logoUrl: asString(json['stream_icon'] ?? json['logo'] ?? json['icon']),
      epgChannelId: asString(json['epg_channel_id'] ?? json['epg_id']),
      hasEpg: asBool(json['tv_archive']) ||
          asString(json['epg_channel_id']) != null,
    );
  }
}

class Episode {
  final int id;
  final String title;
  final int season;
  final int number;
  final String? plot;
  final String extension;
  final int? durationSecs;
  final String? thumbnail;

  const Episode({
    required this.id,
    required this.title,
    required this.season,
    required this.number,
    this.plot,
    this.extension = 'mp4',
    this.durationSecs,
    this.thumbnail,
  });

  factory Episode.fromJson(Map<String, dynamic> json, {int? seasonHint}) {
    final info = asMap(json['info']);
    final season = asInt(json['season'] ?? json['season_number'] ?? seasonHint) ?? 1;
    final number = asInt(
          json['episode_num'] ?? json['episode'] ?? json['episode_number'],
        ) ??
        0;
    return Episode(
      id: asInt(json['id'] ?? json['stream_id'] ?? json['episode_id']) ?? 0,
      title: asString(json['title'] ?? json['name'] ?? info['name']) ??
          'Episodio $number',
      season: season,
      number: number,
      plot: asString(json['plot'] ?? info['plot'] ?? info['description']),
      extension: asString(json['container_extension'] ?? info['container_extension']) ??
          'mp4',
      durationSecs: _durationSecs(json['duration'] ?? info['duration']),
      thumbnail: asString(
        json['movie_image'] ?? info['movie_image'] ?? json['cover'],
      ),
    );
  }
}

class SeriesDetails {
  final SeriesShow show;
  final Map<int, List<Episode>> seasons;

  const SeriesDetails({required this.show, required this.seasons});
}

class EpgProgram {
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;

  const EpgProgram({
    required this.title,
    required this.start,
    required this.end,
    this.description,
  });

  bool get isNow {
    final now = DateTime.now().toUtc();
    return !now.isBefore(start) && now.isBefore(end);
  }

  double get progress {
    final now = DateTime.now().toUtc();
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
  }

  factory EpgProgram.fromJson(Map<String, dynamic> json) {
    var title = asString(json['title'] ?? json['name']) ?? 'Programa';
    var description = asString(json['description'] ?? json['desc']);
    title = _tryDecode(title);
    if (description != null) description = _tryDecode(description);
    return EpgProgram(
      title: title,
      description: description,
      start: asDate(json['start'] ?? json['start_timestamp'] ?? json['start_time']) ??
          DateTime.now().toUtc(),
      end: asDate(json['end'] ?? json['stop'] ?? json['end_timestamp'] ?? json['end_time']) ??
          DateTime.now().toUtc().add(const Duration(minutes: 30)),
    );
  }
}

class AccountInfo {
  final String username;
  final bool active;
  final String status;
  final DateTime? expiresAt;
  final int? maxConnections;
  final int? activeConnections;
  final bool trial;
  final String? serverUrl;
  final String? timezone;

  const AccountInfo({
    required this.username,
    required this.active,
    required this.status,
    this.expiresAt,
    this.maxConnections,
    this.activeConnections,
    this.trial = false,
    this.serverUrl,
    this.timezone,
  });

  factory AccountInfo.fromJson(
    Map<String, dynamic> user,
    Map<String, dynamic> server,
  ) {
    final status = asString(user['status']) ?? (asBool(user['auth']) ? 'Active' : 'Disabled');
    return AccountInfo(
      username: asString(user['username']) ?? '',
      active: asBool(user['auth']) || status.toLowerCase() == 'active',
      status: status,
      expiresAt: asDate(user['exp_date']),
      maxConnections: asInt(user['max_connections']),
      activeConnections: asInt(user['active_cons']),
      trial: asBool(user['is_trial']),
      serverUrl: asString(server['url']),
      timezone: asString(server['timezone']),
    );
  }
}

class WatchEntry {
  final String key;
  final MediaKind kind;
  final int streamId;
  final String title;
  final String? posterUrl;
  final int positionMs;
  final int durationMs;
  final String extension;
  final int? seriesId;
  final int? season;
  final int? episode;
  final DateTime updatedAt;

  const WatchEntry({
    required this.key,
    required this.kind,
    required this.streamId,
    required this.title,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
    this.posterUrl,
    this.extension = 'mp4',
    this.seriesId,
    this.season,
    this.episode,
  });

  double get progress =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'key': key,
        'kind': kind.name,
        'streamId': streamId,
        'title': title,
        'posterUrl': posterUrl,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'extension': extension,
        'seriesId': seriesId,
        'season': season,
        'episode': episode,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WatchEntry.fromJson(Map<String, dynamic> json) {
    return WatchEntry(
      key: asString(json['key']) ?? '',
      kind: MediaKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => MediaKind.vod,
      ),
      streamId: asInt(json['streamId']) ?? 0,
      title: asString(json['title']) ?? '',
      posterUrl: asString(json['posterUrl']),
      positionMs: asInt(json['positionMs']) ?? 0,
      durationMs: asInt(json['durationMs']) ?? 0,
      extension: asString(json['extension']) ?? 'mp4',
      seriesId: asInt(json['seriesId']),
      season: asInt(json['season']),
      episode: asInt(json['episode']),
      updatedAt: asDate(json['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }
}

class Favorite {
  final String key;
  final MediaKind kind;
  final int id;
  final String title;
  final String? posterUrl;
  final String? extension;
  final String? categoryId;

  const Favorite({
    required this.key,
    required this.kind,
    required this.id,
    required this.title,
    this.posterUrl,
    this.extension,
    this.categoryId,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'kind': kind.name,
        'id': id,
        'title': title,
        'posterUrl': posterUrl,
        'extension': extension,
        'categoryId': categoryId,
      };

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      key: asString(json['key']) ?? '',
      kind: MediaKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => MediaKind.vod,
      ),
      id: asInt(json['id']) ?? 0,
      title: asString(json['title']) ?? '',
      posterUrl: asString(json['posterUrl']),
      extension: asString(json['extension']),
      categoryId: asString(json['categoryId']),
    );
  }
}

class PlaybackRequest {
  final String title;
  final MediaKind kind;
  final int streamId;
  final String? posterUrl;
  final String extension;
  final int startAtMs;
  final String? subtitle;
  final int? seriesId;
  final int? season;
  final int? episode;

  const PlaybackRequest({
    required this.title,
    required this.kind,
    required this.streamId,
    required this.extension,
    this.posterUrl,
    this.startAtMs = 0,
    this.subtitle,
    this.seriesId,
    this.season,
    this.episode,
  });
}

String? _yearOf(dynamic value) {
  final text = asString(value);
  if (text == null) return null;
  final match = RegExp(r'(\d{4})').firstMatch(text);
  return match?.group(1);
}

int? _durationSecs(dynamic value) {
  final asNumber = asInt(value);
  if (asNumber != null) {
    if (asNumber > 10000) return asNumber ~/ 1000;
    return asNumber;
  }
  final text = asString(value);
  if (text == null) return null;
  final parts = text.split(':');
  if (parts.length == 3) {
    return (int.tryParse(parts[0]) ?? 0) * 3600 +
        (int.tryParse(parts[1]) ?? 0) * 60 +
        (int.tryParse(parts[2]) ?? 0);
  }
  if (parts.length == 2) {
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
  return null;
}

String _tryDecode(String value) {
  try {
    return decodeMaybeBase64(value);
  } catch (_) {
    return value;
  }
}
