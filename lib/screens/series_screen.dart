import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/content_row.dart';
import '../widgets/poster_card.dart';
import '../widgets/skeletons.dart';
import 'home_screen.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  int _category = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.loadingCatalog && state.series.isEmpty) {
      return const GridSkeleton();
    }
    final labels = ['Todas', ...state.seriesCategories.map((c) => c.name)];
    final categoryId =
        _category == 0 ? null : state.seriesCategories[_category - 1].id;
    final items = state.seriesByCategory(categoryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 12, 28, 8),
          child: Text(
            'Series',
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
              final show = items[index];
              return PosterCard(
                title: show.name,
                imageUrl: show.posterUrl,
                width: 160,
                onTap: () => openSeries(context, show),
              );
            },
          ),
        ),
      ],
    );
  }
}
