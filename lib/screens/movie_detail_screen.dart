import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});

  final Movie movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Movie? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final details =
          await context.read<AppState>().xtream!.vodInfo(widget.movie.streamId);
      if (mounted) {
        setState(() {
          _details = widget.movie.copyWithDetails(details);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = _details ?? widget.movie;
    final state = context.watch<AppState>();
    final fav = state.isFavorite(MediaKind.vod, movie.streamId);
    final image = movie.backdropUrl ?? movie.posterUrl;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
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
                        colors: [Colors.transparent, AppColors.background],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.name,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (movie.year != null) _MetaChip(movie.year!),
                      if (movie.rating != null)
                        _MetaChip('★ ${movie.rating!.toStringAsFixed(1)}'),
                      if (movie.genre != null) _MetaChip(movie.genre!),
                      if (movie.durationSecs != null)
                        _MetaChip(_formatDuration(movie.durationSecs!)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        autofocus: true,
                        onPressed: () => openPlayback(
                          context,
                          PlaybackRequest(
                            title: movie.name,
                            kind: MediaKind.vod,
                            streamId: movie.streamId,
                            posterUrl: movie.posterUrl,
                            extension: movie.extension,
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 26),
                        label: const Text('Reproducir'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => state.toggleFavorite(
                          kind: MediaKind.vod,
                          id: movie.streamId,
                          title: movie.name,
                          posterUrl: movie.posterUrl,
                          extension: movie.extension,
                          categoryId: movie.categoryId,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: Icon(fav ? Icons.check : Icons.add),
                        label: Text(fav ? 'En mi lista' : 'Mi lista'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sinopsis',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const LinearProgressIndicator(color: AppColors.accent)
                  else
                    Text(
                      movie.plot ?? 'Sin sinopsis disponible.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.5,
                        fontSize: 15,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
