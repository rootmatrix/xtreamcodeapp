import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1C1C1F),
      highlightColor: const Color(0xFF2A2A30),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class PosterSkeletonRow extends StatelessWidget {
  const PosterSkeletonRow({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SkeletonBox(width: 140, height: 210, radius: 10),
      ),
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, 12, 28, 28),
            child: SkeletonBox(height: 340, radius: 16),
          ),
        ),
        SliverToBoxAdapter(child: PosterSkeletonRow()),
        SliverToBoxAdapter(child: SizedBox(height: 28)),
        SliverToBoxAdapter(child: PosterSkeletonRow()),
      ],
    );
  }
}

class GridSkeleton extends StatelessWidget {
  const GridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: 18,
      itemBuilder: (_, __) => const SkeletonBox(radius: 10),
    );
  }
}
