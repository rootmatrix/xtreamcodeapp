import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/content_row.dart';
import '../widgets/skeletons.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.loadingCatalog && !state.hasCatalog) {
      return const HomeSkeleton();
    }
    if (state.error != null && !state.hasCatalog) {
      return _ErrorPane(
        message: state.error!,
        onRetry: () => context.read<AppState>().loadCatalogs(),
      );
    }

    final hero = state.popularMovies.isNotEmpty
        ? state.popularMovies.first
        : null;
    final continueItems = state.history.take(18).toList();

    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (hero != null)
          SliverToBoxAdapter(child: _HeroBanner(movie: hero)),
        SliverToBoxAdapter(
          child: ContentRow(
            title: 'Continuar viendo',
            items: [
              for (final item in continueItems)
                ContentRowItem(
                  title: item.title,
                  imageUrl: item.posterUrl,
                  progress: item.progress,
                  onTap: () => openPlayback(
                    context,
                    PlaybackRequest(
                      title: item.title,
                      kind: item.kind,
                      streamId: item.streamId,
                      posterUrl: item.posterUrl,
                      extension: item.extension,
                      startAtMs: item.positionMs,
                      seriesId: item.seriesId,
                      season: item.season,
                      episode: item.episode,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: ContentRow(
            title: 'Películas populares',
            items: [
              for (final movie in state.popularMovies)
                ContentRowItem(
                  title: movie.name,
                  imageUrl: movie.posterUrl,
                  onTap: () => openMovie(context, movie),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: ContentRow(
            title: 'Series populares',
            items: [
              for (final show in state.popularSeries)
                ContentRowItem(
                  title: show.name,
                  imageUrl: show.posterUrl,
                  onTap: () => openSeries(context, show),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: ContentRow(
            title: 'Canales en vivo',
            square: true,
            items: [
              for (final channel in state.featuredLive)
                ContentRowItem(
                  title: channel.name,
                  imageUrl: channel.logoUrl,
                  square: true,
                  onTap: () => openLive(context, channel),
                ),
            ],
          ),
        ),
        if (state.favorites.isNotEmpty)
          SliverToBoxAdapter(
            child: ContentRow(
              title: 'Mi lista',
              items: [
                for (final fav in state.favorites)
                  ContentRowItem(
                    title: fav.title,
                    imageUrl: fav.posterUrl,
                    square: fav.kind == MediaKind.live,
                    onTap: () => _openFavorite(context, state, fav),
                  ),
              ],
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  void _openFavorite(BuildContext context, AppState state, Favorite fav) {
    switch (fav.kind) {
      case MediaKind.vod:
        final movie = state.movieById(fav.id);
        if (movie != null) openMovie(context, movie);
      case MediaKind.series:
        final show = state.seriesById(fav.id);
        if (show != null) openSeries(context, show);
      case MediaKind.live:
        final channel = state.liveById(fav.id);
        if (channel != null) openLive(context, channel);
    }
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final image = movie.backdropUrl ?? movie.posterUrl;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
          else
            const ColoredBox(color: AppColors.surface),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x330B0B0D),
                  Color(0x000B0B0D),
                  Color(0xCC0B0B0D),
                  Color(0xFF0B0B0D),
                ],
                stops: [0, 0.35, 0.72, 1],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 0, 36, 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (movie.genre != null || movie.year != null)
                      Text(
                        [
                          if (movie.year != null) movie.year,
                          if (movie.genre != null) movie.genre,
                          if (movie.rating != null)
                            '★ ${movie.rating!.toStringAsFixed(1)}',
                        ].join('  ·  '),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      movie.name,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    if (movie.plot != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        movie.plot!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.45,
                          fontSize: 15,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => openMovie(context, movie, play: true),
                          icon: const Icon(Icons.play_arrow_rounded, size: 26),
                          label: const Text('Reproducir'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => openMovie(context, movie),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Más información'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

void openMovie(BuildContext context, Movie movie, {bool play = false}) {
  if (play) {
    openPlayback(
      context,
      PlaybackRequest(
        title: movie.name,
        kind: MediaKind.vod,
        streamId: movie.streamId,
        posterUrl: movie.posterUrl,
        extension: movie.extension,
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
  );
}

void openSeries(BuildContext context, SeriesShow show) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SeriesDetailScreen(show: show)),
  );
}

void openLive(BuildContext context, LiveChannel channel) {
  openPlayback(
    context,
    PlaybackRequest(
      title: channel.name,
      kind: MediaKind.live,
      streamId: channel.streamId,
      posterUrl: channel.logoUrl,
      extension: 'm3u8',
    ),
  );
}

void openPlayback(BuildContext context, PlaybackRequest request) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => PlayerScreen(request: request),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}
