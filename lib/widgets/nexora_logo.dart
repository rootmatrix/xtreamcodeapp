import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class NexoraLogo extends StatelessWidget {
  const NexoraLogo({
    super.key,
    this.height = 36,
    this.showWordmark = true,
  });

  final double height;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/logo.png',
          height: height,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Container(
            width: height,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'N',
              style: GoogleFonts.bebasNeue(
                fontSize: height * 0.72,
                height: 1,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          Text(
            'NEXORA',
            style: GoogleFonts.bebasNeue(
              fontSize: height * 0.82,
              letterSpacing: 2.4,
              height: 1,
              color: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}
