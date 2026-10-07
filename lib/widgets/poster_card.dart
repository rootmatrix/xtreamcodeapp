import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.progress,
    this.square = false,
    this.width = 148,
    this.autofocus = false,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback onTap;
  final double? progress;
  final bool square;
  final double width;
  final bool autofocus;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _focused || _hovered ? 1.06 : 1.0;
    final height = widget.square ? widget.width : widget.width * 1.5;

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: SizedBox(
              width: widget.width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: height,
                    width: widget.width,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _focused ? AppColors.accent : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: _focused || _hovered
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.55),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ]
                          : const [],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: AppColors.surfaceHigh,
                          child: widget.imageUrl == null || widget.imageUrl!.isEmpty
                              ? _fallback()
                              : CachedNetworkImage(
                                  imageUrl: widget.imageUrl!,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 280),
                                  placeholder: (_, __) => const ColoredBox(
                                    color: AppColors.surfaceHigh,
                                  ),
                                  errorWidget: (_, __, ___) => _fallback(),
                                ),
                        ),
                        if (widget.progress != null)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              value: widget.progress!.clamp(0, 1),
                              color: AppColors.accent,
                              backgroundColor: const Color(0x66000000),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.surfaceHigh,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: Text(
        widget.title,
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
