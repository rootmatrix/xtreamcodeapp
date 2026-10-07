import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.show});

  final SeriesShow show;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesDetails? _details;
  int? _season;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final details =
          await context.read<AppState>().xtream!.seriesInfo(widget.show.seriesId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _season = details.seasons.keys.isEmpty
            ? null
            : (details.seasons.keys.toList()..sort()).first;
        _loading = false;
      });
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = _details?.show ?? widget.show;
    final state = context.watch<AppState>();
    final fav = state.isFavorite(MediaKind.series, widget.show.seriesId);
    final image = show.backdropUrl ?? show.posterUrl;
    final seasons = _details?.seasons ?? {};
    final seasonKeys = seasons.keys.toList()..sort();
    final episodes = _season == null ? const <Episode>[] : seasons[_season] ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
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
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.name,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      if (show.year != null) _chip(show.year!),
                      if (show.rating != null)
                        _chip('★ ${show.rating!.toStringAsFixed(1)}'),
                      if (show.genre != null) _chip(show.genre!),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => state.toggleFavorite(
                      kind: MediaKind.series,
                      id: widget.show.seriesId,
                      title: show.name,
                      posterUrl: show.posterUrl,
                      categoryId: show.categoryId,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    icon: Icon(fav ? Icons.check : Icons.add),
                    label: Text(fav ? 'En mi lista' : 'Mi lista'),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    show.plot ?? 'Sin sinopsis disponible.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Temporadas',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const LinearProgressIndicator(color: AppColors.accent)
                  else if (_error != null)
                    Text(_error!, style: const TextStyle(color: AppColors.muted))
                  else
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: seasonKeys.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final number = seasonKeys[index];
                          final on = number == _season;
                          return ChoiceChip(
                            label: Text('T$number'),
                            selected: on,
                            onSelected: (_) => setState(() => _season = number),
                            selectedColor: AppColors.accent,
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              final episode = episodes[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 6,
                ),
                leading: episode.thumbnail == null
                    ? CircleAvatar(
                        backgroundColor: AppColors.surfaceHigh,
                        child: Text('${episode.number}'),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: episode.thumbnail!,
                          width: 92,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                title: Text(
                  '${episode.number}. ${episode.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  episode.plot ??
                      (episode.durationSecs == null
                          ? 'Temporada ${episode.season}'
                          : '${episode.durationSecs! ~/ 60} min'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.play_arrow_rounded),
                onTap: () => openPlayback(
                  context,
                  PlaybackRequest(
                    title: '${show.name} · T${episode.season}E${episode.number}',
                    kind: MediaKind.series,
                    streamId: episode.id,
                    posterUrl: episode.thumbnail ?? show.posterUrl,
                    extension: episode.extension,
                    subtitle: episode.title,
                    seriesId: widget.show.seriesId,
                    season: episode.season,
                    episode: episode.number,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}
