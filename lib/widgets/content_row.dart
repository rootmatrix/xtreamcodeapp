import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'poster_card.dart';

class ContentRowItem {
  const ContentRowItem({
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.progress,
    this.square = false,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback onTap;
  final double? progress;
  final bool square;
}

class ContentRow extends StatelessWidget {
  const ContentRow({
    super.key,
    required this.title,
    required this.items,
    this.square = false,
  });

  final String title;
  final List<ContentRowItem> items;
  final bool square;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          SizedBox(
            height: square ? 196 : 268,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return PosterCard(
                  title: item.title,
                  imageUrl: item.imageUrl,
                  onTap: item.onTap,
                  progress: item.progress,
                  square: square || item.square,
                  autofocus: index == 0 && title.startsWith('Continuar'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isOn = selected == index;
          return ChoiceChip(
            label: Text(labels[index]),
            selected: isOn,
            onSelected: (_) => onSelected(index),
            selectedColor: AppColors.accent,
            labelStyle: TextStyle(
              color: isOn ? Colors.white : AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: AppColors.surfaceHigh,
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
