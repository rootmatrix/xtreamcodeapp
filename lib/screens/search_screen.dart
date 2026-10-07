import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_card.dart';
import 'home_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final results = state.searchAll(_query);
    final movies = results.whereType<Movie>().toList();
    final shows = results.whereType<SeriesShow>().toList();
    final channels = results.whereType<LiveChannel>().toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Busca películas, series o canales',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _query.trim().isEmpty
              ? const Center(
                  child: Text(
                    'Escribe un título para buscar en todo el catálogo.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : results.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin resultados.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        if (movies.isNotEmpty)
                          _Section(
                            title: 'Películas (${movies.length})',
                            child: _Strip(
                              children: [
                                for (final movie in movies.take(40))
                                  PosterCard(
                                    title: movie.name,
                                    imageUrl: movie.posterUrl,
                                    onTap: () => openMovie(context, movie),
                                  ),
                              ],
                            ),
                          ),
                        if (shows.isNotEmpty)
                          _Section(
                            title: 'Series (${shows.length})',
                            child: _Strip(
                              children: [
                                for (final show in shows.take(40))
                                  PosterCard(
                                    title: show.name,
                                    imageUrl: show.posterUrl,
                                    onTap: () => openSeries(context, show),
                                  ),
                              ],
                            ),
                          ),
                        if (channels.isNotEmpty)
                          _Section(
                            title: 'En vivo (${channels.length})',
                            child: _Strip(
                              children: [
                                for (final channel in channels.take(40))
                                  PosterCard(
                                    title: channel.name,
                                    imageUrl: channel.logoUrl,
                                    square: true,
                                    onTap: () => openLive(context, channel),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 10),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 268,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) => children[index],
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: children.length,
      ),
    );
  }
}
