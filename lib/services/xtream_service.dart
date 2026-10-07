import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:muxa_xtream/muxa_xtream.dart';

import '../core/constants.dart';
import '../core/json_util.dart';
import '../models/catalog.dart';

class XtreamException implements Exception {
  final String message;
  const XtreamException(this.message);

  @override
  String toString() => message;
}

class XtreamService {
  XtreamService({
    required this.server,
    required this.username,
    required this.password,
    http.Client? httpClient,
  })  : portal = XtreamPortal.parse(server),
        credentials = XtreamCredentials(username: username, password: password),
        _http = httpClient ?? http.Client() {
    client = XtreamClient(
      portal,
      credentials,
      options: const XtreamClientOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        userAgent: AppConstants.userAgent,
      ),
    );
  }

  final String server;
  final String username;
  final String password;
  final XtreamPortal portal;
  final XtreamCredentials credentials;
  final http.Client _http;
  late final XtreamClient client;

  static String normalizeServer(String input) {
    var url = input.trim();
    if (url.isEmpty) {
      throw const XtreamException('La URL del servidor está vacía.');
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw const XtreamException('URL de servidor no válida.');
    }
    return url;
  }

  Future<AccountInfo> authenticate() async {
    try {
      final info = await client.getUserAndServerInfo();
      final account = AccountInfo(
        username: info.user.username,
        active: info.user.active,
        status: info.user.active ? 'Active' : 'Disabled',
        expiresAt: info.user.expiresAt,
        maxConnections: info.user.maxConnections,
        trial: info.user.trial ?? false,
        serverUrl: info.server.baseUrl.toString(),
      );
      if (!account.active) {
        throw const XtreamException('La cuenta no está activa.');
      }
      return account;
    } on XtreamException {
      rethrow;
    } on XtAuthError catch (err) {
      throw XtreamException('Credenciales rechazadas: $err');
    } catch (_) {
      return _authenticateRaw();
    }
  }

  Future<AccountInfo> _authenticateRaw() async {
    final data = await _getJson();
    if (data is! Map<String, dynamic>) {
      throw const XtreamException('Respuesta inesperada del portal.');
    }
    final user = asMap(data['user_info']);
    final serverInfo = asMap(data['server_info']);
    if (user.isEmpty) {
      throw const XtreamException('No se pudo validar la cuenta.');
    }
    final account = AccountInfo.fromJson(user, serverInfo);
    if (!account.active) {
      throw XtreamException(
        'Cuenta inactiva (${account.status}). Revisa tu panel XUI.',
      );
    }
    return account;
  }

  Future<List<Category>> liveCategories() =>
      _categories('get_live_categories', MediaKind.live);

  Future<List<Category>> vodCategories() =>
      _categories('get_vod_categories', MediaKind.vod);

  Future<List<Category>> seriesCategories() =>
      _categories('get_series_categories', MediaKind.series);

  Future<List<Category>> _categories(String action, MediaKind kind) async {
    final data = await _getJson(action: action);
    return asMapList(data).map((json) => Category.fromJson(json, kind)).toList();
  }

  Future<List<LiveChannel>> liveStreams({String? categoryId}) async {
    final data = await _getJson(
      action: 'get_live_streams',
      extra: {if (categoryId != null) 'category_id': categoryId},
    );
    return asMapList(data).map(LiveChannel.fromJson).toList();
  }

  Future<List<Movie>> vodStreams({String? categoryId}) async {
    final data = await _getJson(
      action: 'get_vod_streams',
      extra: {if (categoryId != null) 'category_id': categoryId},
    );
    return asMapList(data).map(Movie.fromJson).toList();
  }

  Future<List<SeriesShow>> seriesList({String? categoryId}) async {
    final data = await _getJson(
      action: 'get_series',
      extra: {if (categoryId != null) 'category_id': categoryId},
    );
    return asMapList(data).map(SeriesShow.fromJson).toList();
  }

  Future<Movie> vodInfo(int vodId) async {
    try {
      final details = await client.getVodInfo(vodId);
      return Movie(
        streamId: details.streamId == 0 ? vodId : details.streamId,
        name: details.name,
        categoryId: '',
        posterUrl: details.posterUrl,
        plot: details.plot,
        rating: details.rating,
        year: details.year?.toString(),
        genre: details.genre,
        durationSecs: details.duration?.inSeconds,
      );
    } catch (_) {
      final data = await _getJson(
        action: 'get_vod_info',
        extra: {'vod_id': '$vodId'},
      );
      final map = asMap(data);
      final info = asMap(map['info']);
      final movieData = asMap(map['movie_data']);
      return Movie.fromJson({...movieData, ...map, ...info});
    }
  }

  Future<SeriesDetails> seriesInfo(int seriesId) async {
    final data = await _getJson(
      action: 'get_series_info',
      extra: {'series_id': '$seriesId'},
    );
    final map = asMap(data);
    final info = asMap(map['info']);
    final show = SeriesShow.fromJson({
      ...info,
      ...map,
      'series_id': seriesId,
    });
    final seasons = <int, List<Episode>>{};
    final episodes = map['episodes'];
    if (episodes is Map) {
      episodes.forEach((key, value) {
        final seasonNum = asInt(key) ?? 0;
        final list = value is List ? value : const [];
        seasons[seasonNum] = list
            .whereType<Map>()
            .map(
              (item) => Episode.fromJson(
                Map<String, dynamic>.from(item),
                seasonHint: seasonNum,
              ),
            )
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));
      });
    }
    return SeriesDetails(show: show, seasons: seasons);
  }

  Future<List<EpgProgram>> shortEpg(LiveChannel channel, {int limit = 6}) async {
    try {
      final entries = await client.getShortEpg(
        streamId: channel.streamId,
        epgChannelId: channel.epgChannelId,
        limit: limit,
      );
      return entries
          .map(
            (entry) => EpgProgram(
              title: entry.title,
              description: entry.description,
              start: entry.startUtc,
              end: entry.endUtc,
            ),
          )
          .toList();
    } catch (_) {
      final data = await _getJson(
        action: 'get_short_epg',
        extra: {
          'stream_id': '${channel.streamId}',
          if (channel.epgChannelId != null)
            'epg_channel_id': channel.epgChannelId!,
          'limit': '$limit',
        },
      );
      List list;
      if (data is List) {
        list = data;
      } else {
        final map = asMap(data);
        list = (map['epg_listings'] ?? map['listings'] ?? []) as List? ?? [];
      }
      return asMapList(list).map(EpgProgram.fromJson).toList();
    }
  }

  List<Uri> playbackUrls({
    required MediaKind kind,
    required int streamId,
    String extension = 'mp4',
  }) {
    final ext = extension.replaceAll('.', '').trim().isEmpty
        ? 'mp4'
        : extension.replaceAll('.', '').trim();
    switch (kind) {
      case MediaKind.live:
        return [
          liveUrl(portal, credentials, streamId, extension: 'm3u8'),
          liveUrl(portal, credentials, streamId, extension: 'ts'),
        ];
      case MediaKind.vod:
        return [
          vodUrl(portal, credentials, streamId, extension: 'm3u8'),
          vodUrl(portal, credentials, streamId, extension: ext),
          if (ext != 'ts') vodUrl(portal, credentials, streamId, extension: 'ts'),
        ];
      case MediaKind.series:
        return [
          seriesUrl(portal, credentials, streamId, extension: 'm3u8'),
          seriesUrl(portal, credentials, streamId, extension: ext),
          if (ext != 'ts')
            seriesUrl(portal, credentials, streamId, extension: 'ts'),
        ];
    }
  }

  Future<dynamic> _getJson({
    String? action,
    Map<String, String> extra = const {},
  }) async {
    final uri = portal.baseUri.replace(
      path: [
        ...portal.baseUri.pathSegments.where((s) => s.isNotEmpty),
        'player_api.php',
      ].join('/'),
      queryParameters: {
        'username': username,
        'password': password,
        if (action != null) 'action': action,
        ...extra,
      },
    );
    try {
      final response = await _http.get(
        uri,
        headers: {
          'Accept': 'application/json, text/plain;q=0.9, */*;q=0.1',
          'User-Agent': AppConstants.userAgent,
          'Connection': 'close',
        },
      ).timeout(AppConstants.receiveTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw XtreamException('HTTP ${response.statusCode} al contactar el portal.');
      }
      final body = utf8.decode(response.bodyBytes);
      if (body.trim().isEmpty) return const [];
      return jsonDecode(body);
    } on XtreamException {
      rethrow;
    } catch (err) {
      throw XtreamException('No se pudo conectar con el portal: $err');
    }
  }

  void close() {
    _http.close();
  }
}
