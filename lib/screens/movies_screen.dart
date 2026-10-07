import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/content_row.dart';
import '../widgets/poster_card.dart';
import '../widgets/skeletons.dart';
import 'home_screen.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  int _category = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.loadingCatalog && state.movies.isEmpty) {
      return const GridSkeleton();
    }
    final labels = ['Todas', ...state.vodCategories.map((c) => c.name)];
    final categoryId =
        _category == 0 ? null : state.vodCategories[_category - 1].id;
    final items = state.moviesByCategory(categoryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 12, 28, 8),
          child: Text(
            'Películas',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
        CategoryChips(
          labels: labels,
          selected: _category.clamp(0, labels.length - 1),
          onSelected: (index) => setState(() => _category = index),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              childAspectRatio: 0.58,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final movie = items[index];
              return PosterCard(
                title: movie.name,
                imageUrl: movie.posterUrl,
                width: 160,
                onTap: () => openMovie(context, movie),
              );
            },
          ),
        ),
      ],
    );
  }
}
